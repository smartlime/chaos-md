//! Отображение оставшегося времени тестов и ETA окончания.

use chrono::{DateTime, Local, Duration as ChronoDuration, Timelike};
use ratatui::layout::Rect;
use ratatui::style::{Color, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::Paragraph;
use ratatui::Frame;

use crate::app::App;
use crate::queue::{build, Step};

pub fn draw(f: &mut Frame, app: &App, area: Rect) {
    let (ete_seconds, show_ete) = match &app.runner {
        crate::app::RunnerStatus::Running { step_idx, started_at, .. } => {
            let elapsed = started_at.elapsed().as_secs() as u32;
            let step = app.queue.get(*step_idx);
            let current_duration = if let Some(s) = step {
                match s {
                    Step::Run { .. } => app.time_test_s,
                    Step::Pause { seconds, .. } => *seconds,
                    Step::Teardown { .. } => 5,
                }
            } else {
                0
            };

            let remaining_current = current_duration.saturating_sub(elapsed);
            let mut remaining_future = 0u32;

            for (i, s) in app.queue.iter().enumerate() {
                if i > *step_idx {
                    match s {
                        Step::Run { .. } => remaining_future += app.time_test_s,
                        Step::Pause { seconds, .. } => remaining_future += seconds,
                        Step::Teardown { .. } => {}
                    }
                }
            }

            (remaining_current + remaining_future, true)
        }
        crate::app::RunnerStatus::Idle => {
            let queue = build(&app.selected, app.phases, app.time_wait_s);
            let mut total = 0u32;
            for step in &queue {
                match step {
                    Step::Run { .. } => total += app.time_test_s,
                    Step::Pause { seconds, .. } => total += seconds,
                    Step::Teardown { .. } => {}
                }
            }
            (total, total > 0)
        }
        _ => (0, false),
    };

    let (tag_bg, text_fg) = if matches!(app.runner, crate::app::RunnerStatus::Idle) {
        (crate::theme::DIM, Color::Gray)
    } else {
        (crate::theme::FOCUS, crate::theme::FOCUS_FG)
    };

    let (ete_tag, ete_val) = if !show_ete {
        (" ETE ", "00:00".to_string())
    } else {
        let days = ete_seconds / 86400;
        let hours = (ete_seconds % 86400) / 3600;
        let minutes = (ete_seconds % 3600) / 60;
        let secs = ete_seconds % 60;

        let val = if days > 0 {
            format!("{}д {}:{:02}:{:02}", days, hours, minutes, secs)
        } else if ete_seconds < 3600 {
            format!("{}:{:02}", minutes, secs)
        } else {
            format!("{}:{:02}:{:02}", hours, minutes, secs)
        };
        (" ETE ", val)
    };

    let (eta_tag, eta_val) = if show_ete && ete_seconds > 0 {
        let now: DateTime<Local> = Local::now();
        let eta = now + ChronoDuration::seconds(ete_seconds as i64);
        (" ETA ", format!("{:02}:{:02}", eta.hour(), eta.minute()))
    } else {
        ("", String::new())
    };

    let ete_area = Rect {
        x: area.x + 1,
        y: area.y,
        width: area.width.saturating_sub(2),
        height: 1,
    };

    let eta_area = Rect {
        x: area.x + 1,
        y: area.y + 1,
        width: area.width.saturating_sub(2),
        height: 1,
    };

    let val_bg = crate::theme::CYBER_GRAY;

    let ete_padding = ete_area.width.saturating_sub(ete_tag.chars().count() as u16 + ete_val.chars().count() as u16);
    let ete_line = Line::from(vec![
        Span::styled(ete_tag, Style::default().bg(tag_bg).fg(Color::Black)),
        Span::styled(format!("{}{}", " ".repeat(ete_padding as usize), ete_val), Style::default().bg(val_bg).fg(text_fg)),
    ]);
    f.render_widget(Paragraph::new(ete_line), ete_area);

    if !eta_tag.is_empty() {
        let eta_padding = eta_area.width.saturating_sub(eta_tag.chars().count() as u16 + eta_val.chars().count() as u16);
        let eta_line = Line::from(vec![
            Span::styled(eta_tag, Style::default().bg(tag_bg).fg(Color::Black)),
            Span::styled(format!("{}{}", " ".repeat(eta_padding as usize), eta_val), Style::default().bg(val_bg).fg(text_fg)),
        ]);
        f.render_widget(Paragraph::new(eta_line), eta_area);
    }
}
