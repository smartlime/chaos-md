//! Состояние приложения.

use std::collections::VecDeque;
use std::path::PathBuf;
use std::time::{Duration, Instant};

use chrono::{DateTime, Local};
use ratatui::text::Line;

use crate::catalog::CATALOG;
use crate::queue::{Phases, Step};

/// Какая зона UI в фокусе.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Focus {
    Selector,
    Log,
    Timeline,
}

/// Что выделено в Selector.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SelectorItem {
    /// Тест по индексу в CATALOG (0..12).
    Test(usize),
    PhaseNode,
    PhaseDc,
    DryRun,
    TimeTest,
    TimeWait,
    Start,
}

impl SelectorItem {
    /// Полный список итемов в порядке навигации сверху вниз.
    pub fn all() -> Vec<SelectorItem> {
        let mut v: Vec<_> = (0..CATALOG.len()).map(SelectorItem::Test).collect();
        v.push(SelectorItem::PhaseNode);
        v.push(SelectorItem::PhaseDc);
        v.push(SelectorItem::DryRun);
        v.push(SelectorItem::TimeTest);
        v.push(SelectorItem::TimeWait);
        v.push(SelectorItem::Start);
        v
    }
}

#[derive(Debug, Clone)]
pub enum RunnerStatus {
    Idle,
    /// step_idx — индекс в queue; started_at — когда начался текущий шаг.
    Running { step_idx: usize, started_at: Instant, started_wall: DateTime<Local> },
    /// Завершено успешно или с ошибкой; через несколько секунд возвращаемся к Idle.
    Finished { ok: bool, at: Instant },
}

#[derive(Debug, Default, Clone)]
pub struct CurrentEvent {
    pub kind: String,             // "CHAOS_START"
    pub started_wall: Option<DateTime<Local>>,
    pub raw_details: String,      // "net delay  scope=dc  hosts=4  delay=50ms  timeout=600s"
    pub timeout_s: Option<u32>,   // спарсенный timeout=
    pub scope: Option<String>,
    pub hosts: Option<u32>,
}

/// Состояние диалогового окна Check (-C).
pub struct CheckDialog {
    pub title: String,
    pub lines: Vec<String>,
    pub scroll: usize, // визуальные строки (после wrap), 0 = top
    pub loading: bool,
}

pub struct App {
    pub repo_root: PathBuf,
    pub log_dir: PathBuf,
    pub timeline_path: PathBuf,

    // selector
    pub selected: Vec<bool>,
    pub phases: Phases,
    pub time_test_s: u32,
    pub time_wait_s: u32,
    pub selector_idx: usize, // индекс в SelectorItem::all()

    // фокус
    pub focus: Focus,

    // лог теста (центральная зона)
    pub log_lines: VecDeque<Line<'static>>,
    pub log_current: Option<String>,
    pub log_scroll: usize, // 0 = к низу
    pub log_max: usize,

    // timeline (нижняя зона)
    pub timeline_lines: VecDeque<Line<'static>>,
    pub timeline_scroll: usize,
    pub timeline_max: usize,

    // status (правый-низ)
    pub current_event: Option<CurrentEvent>,

    // очередь и runner
    pub queue: Vec<Step>,
    pub runner: RunnerStatus,

    // dry-run: пропихиваем --dry-run в каждый bash-вызов
    pub dry_run: bool,

    // подтверждение выхода
    pub quit_pending: bool,

    // флаг «надо выйти после следующего тика»
    pub should_quit: bool,

    // диалог Check: Some = открыт
    pub check_dialog: Option<CheckDialog>,
    // запрос на открытие диалога (test_idx в CATALOG)
    pub pending_check: Option<usize>,

    // диалог конфигурации
    pub config_dialog_open: bool,

    // остановка текущей очереди тестов
    pub chaos_started_at: Option<Instant>,
    pub force_redraw: bool,
    pub stop_requested: bool,

    // индексы завершённых тестов (для отображения галок)
    pub finished_tests: Vec<bool>,
}

impl App {
    pub fn new(repo_root: PathBuf) -> Self {
        let log_dir = repo_root.join("logs");
        let timeline_path = log_dir.join("timeline.log");
        Self {
            repo_root,
            log_dir,
            timeline_path,
            selected: vec![false; CATALOG.len()],
            phases: Phases { node: true, dc: true, dc_alt: false },
            time_test_s: 1200,
            time_wait_s: 600,
            selector_idx: 0,
            focus: Focus::Selector,
            log_lines: VecDeque::new(),
            log_current: None,
            log_scroll: 0,
            log_max: 10_000,
            timeline_lines: VecDeque::new(),
            timeline_scroll: 0,
            timeline_max: 5_000,
            current_event: None,
            queue: Vec::new(),
            runner: RunnerStatus::Idle,
            dry_run: true,
            quit_pending: false,
            should_quit: false,
            check_dialog: None,
            pending_check: None,
            config_dialog_open: false,
            chaos_started_at: None,
            force_redraw: false,
            stop_requested: false,
            finished_tests: vec![false; CATALOG.len()],
        }
    }

    pub fn current_selector_item(&self) -> SelectorItem {
        SelectorItem::all()[self.selector_idx]
    }

    pub fn selector_move(&mut self, delta: isize) {
        let n = SelectorItem::all().len() as isize;
        let mut i = self.selector_idx as isize + delta;
        if i < 0 { i = 0; }
        if i >= n { i = n - 1; }
        self.selector_idx = i as usize;
    }

    /// Текущий running step, если есть.
    pub fn running_step(&self) -> Option<(&Step, Instant)> {
        if let RunnerStatus::Running { step_idx, started_at, .. } = &self.runner {
            self.queue.get(*step_idx).map(|s| (s, *started_at))
        } else {
            None
        }
    }

    pub fn step_count(&self) -> (usize, usize) {
        match &self.runner {
            RunnerStatus::Running { step_idx, .. } => (step_idx + 1, self.queue.len()),
            _ => (0, self.queue.len()),
        }
    }

    pub fn is_running(&self) -> bool {
        matches!(self.runner, RunnerStatus::Running { .. })
    }
}

/// Сколько секунд прошло с момента старта current_event (CHAOS_START).
pub fn elapsed_since(started: DateTime<Local>) -> u32 {
    let now = Local::now();
    (now - started).num_seconds().max(0) as u32
}

pub fn fmt_hms(s: u32) -> String {
    if s >= 3600 {
        format!("{:02}:{:02}:{:02}", s / 3600, (s % 3600) / 60, s % 60)
    } else {
        format!("{:02}:{:02}", s / 60, s % 60)
    }
}

#[allow(dead_code)]
pub const TICK: Duration = Duration::from_millis(250);
