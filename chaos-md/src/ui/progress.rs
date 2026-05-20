//! Прогресс-бары текущего теста и всей очереди.

use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::Style;
use ratatui::widgets::Paragraph;
use ratatui::Frame;
use ratatui_braille_bar::BrailleBar;

use crate::app::{App, RunnerStatus};
use crate::queue::Step;
use crate::theme;

pub fn draw(f: &mut Frame, app: &App, area: Rect) {
    let inner = area;

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(1), Constraint::Length(1)])
        .split(inner);

    // 1. Прогресс текущего шага
    let (step_progress, step_label) = match &app.runner {
        RunnerStatus::Running { started_at, step_idx, .. } => {
            let elapsed = started_at.elapsed().as_secs_f64();
            let step = &app.queue[*step_idx];
            let duration = match step {
                Step::Run { .. } => app.time_test_s as f64,
                Step::Pause { seconds, .. } => *seconds as f64,
                Step::Teardown { .. } => 5.0, // Примерное время
            };
            let ratio = (elapsed / duration).clamp(0.0, 1.0);
            (ratio, format!("Текущий шаг: {:.0}%", ratio * 100.0))
        }
        _ => (0.0, "Ожидание...".to_string()),
    };

    // 2. Общий прогресс
    let (total_progress, total_label) = match &app.runner {
        RunnerStatus::Running { step_idx, .. } => {
            let mut total_duration = 0.0;
            let mut current_duration = 0.0;
            
            for (i, step) in app.queue.iter().enumerate() {
                let duration = match step {
                    Step::Run { .. } => app.time_test_s as f64,
                    Step::Pause { seconds, .. } => *seconds as f64,
                    Step::Teardown { .. } => 5.0,
                };
                total_duration += duration;
                if i < *step_idx {
                    current_duration += duration;
                } else if i == *step_idx {
                    if let RunnerStatus::Running { started_at, .. } = &app.runner {
                        current_duration += started_at.elapsed().as_secs_f64().min(duration);
                    }
                }
            }
            
            let ratio = if total_duration > 0.0 {
                (current_duration / total_duration).clamp(0.0, 1.0)
            } else {
                0.0
            };
            (ratio, format!("Общий прогресс: {:.0}%", ratio * 100.0))
        }
        RunnerStatus::Finished { .. } => (1.0, "Завершено".to_string()),
        RunnerStatus::Idle => (0.0, "Ожидание...".to_string()),
    };

    // Отрисовка
    // Пока используем простые LineGauge или кастомные строки, так как ratatui-braille-bar может требовать специфичной настройки
    // Попробуем использовать BrailleBar
    
    // Текущий шаг
    let step_layout = Layout::default().direction(Direction::Horizontal).constraints([Constraint::Length(22), Constraint::Min(0)]).split(chunks[0]);
    f.render_widget(Paragraph::new(step_label).style(Style::default().fg(theme::DIM)), step_layout[0]);
    f.render_widget(
        BrailleBar::new(step_progress, 1.0)
            .fill_color(theme::ACCENT)
            .empty_color(theme::CYBER_GRAY),
        step_layout[1]
    );
    
    // Общий прогресс
    let total_layout = Layout::default().direction(Direction::Horizontal).constraints([Constraint::Length(22), Constraint::Min(0)]).split(chunks[1]);
    f.render_widget(Paragraph::new(total_label).style(Style::default().fg(theme::DIM)), total_layout[0]);
    
    // Используем peak для подсветки текущего теста
    let peak_pos = if total_progress > 0.0 && total_progress < 1.0 {
        total_progress
    } else {
        0.0
    };
    
    f.render_widget(
        BrailleBar::new(total_progress, 1.0)
            .fill_color(theme::OK)
            .empty_color(theme::CYBER_GRAY)
            .peak_color(theme::FOCUS_FG)
            .peak(peak_pos),
        total_layout[1]
    );
}
