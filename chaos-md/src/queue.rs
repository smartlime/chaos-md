//! Построение очереди шагов из выбора пользователя.

use crate::catalog::{Scope, TestEntry, CATALOG};

#[derive(Debug, Clone)]
pub enum Step {
    Run { test_idx: usize, scope: Scope },
    Teardown { test_idx: usize },
    Pause { seconds: u32, after_test_idx: Option<usize> },
}

#[derive(Debug, Clone, Copy, Default)]
pub struct Phases {
    pub node: bool,
    pub dc: bool,
    pub dc_alt: bool,
}

impl Phases {
    pub fn enabled(&self, s: Scope) -> bool {
        match s {
            Scope::Node => self.node,
            Scope::Dc => self.dc,
            Scope::DcAlt => self.dc_alt,
        }
    }
}

pub fn build(selected: &[bool], phases: Phases, time_wait_s: u32) -> Vec<Step> {
    // Сначала собираем только реально выполнимые тесты (у которых есть хотя бы одна фаза).
    let runnable: Vec<(usize, Vec<Scope>)> = selected
        .iter()
        .enumerate()
        .filter_map(|(i, &picked)| {
            if !picked { return None; }
            let steps: Vec<_> = CATALOG[i].scopes.iter().copied()
                .filter(|s| phases.enabled(*s)).collect();
            if steps.is_empty() { None } else { Some((i, steps)) }
        })
        .collect();

    let mut out = Vec::new();
    let last_pos = runnable.len().saturating_sub(1);

    for (pos, (idx, phase_steps)) in runnable.into_iter().enumerate() {
        let test: &TestEntry = &CATALOG[idx];
        for sc in &phase_steps {
            out.push(Step::Run { test_idx: idx, scope: *sc });
        }
        if test.needs_teardown {
            out.push(Step::Teardown { test_idx: idx });
        }
        if pos < last_pos {
            out.push(Step::Pause { seconds: time_wait_s, after_test_idx: Some(idx) });
        }
    }
    out
}
