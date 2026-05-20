//! Нижняя зона: tail logs/timeline.log + прогресс-бар всей очереди.

use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState};
use ratatui::Frame;
use ratatui_braille_bar::BrailleBar;

use crate::app::{App, Focus, RunnerStatus};
use crate::queue::Step;
use crate::theme;

pub fn draw(f: &mut Frame, app: &App, area: Rect) {
    let focused = app.focus == Focus::Timeline;
    let block = Block::default()
        .title(Span::styled(" ♦ Timeline ", theme::block_title(focused)))
        .borders(Borders::ALL)
        .border_style(theme::block_border(focused));
    let inner = block.inner(area);
    f.render_widget(block, area);

    // Разделяем область: таймлайн сверху, прогресс-бар всей очереди снизу
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(0), Constraint::Length(1)])
        .split(inner);

    let timeline_area = chunks[0];
    let progress_area = chunks[1];

    let lines: Vec<Line> = app.timeline_lines.iter().cloned().collect();

    if lines.is_empty() {
        let p = Paragraph::new(Line::from(Span::styled(
            "Timeline пока пуст (logs/timeline.log)",
            ratatui::style::Style::default().fg(theme::DIM),
        )));
        f.render_widget(p, timeline_area);
        
        // Рисуем прогресс-бар всей очереди под таймлайном
        let (total_progress, _) = match &app.runner {
            RunnerStatus::Running { step_idx, started_at, .. } => {
                let mut total_duration = 0.0;
                let mut current_duration = 0.0;

                for (i, step) in app.queue.iter().enumerate() {
                    let duration = match step {
                        Step::Run { .. } => app.time_test_s as f64,
                        Step::Pause { seconds, .. } => *seconds as f64,
                        Step::Teardown { .. } => 5.0, // Примерное время
                    };
                    total_duration += duration;
                    if i < *step_idx {
                        current_duration += duration;
                    } else if i == *step_idx {
                        // Добавляем часть текущего шага
                        let elapsed = started_at.elapsed().as_secs_f64();
                        current_duration += elapsed.min(duration);
                    }
                }
                
                let ratio = if total_duration > 0.0 { current_duration / total_duration } else { 0.0 };
                (ratio, format!("Общий прогресс: {:.0}%", ratio * 100.0))
            }
            _ => (0.0, "Ожидание...".to_string()),
        };
        
        f.render_widget(BrailleBar::new(total_progress, 1.0).fill_color(theme::ACCENT), progress_area);
        return;
    }

    let total = lines.len();
    let viewport = timeline_area.height as usize;
    let scroll = app.timeline_scroll.min(total.saturating_sub(viewport));
    let bottom = total.saturating_sub(scroll);
    let top = bottom.saturating_sub(viewport);
    let visible = lines[top..bottom].to_vec();

    let p = Paragraph::new(visible);
    f.render_widget(p, timeline_area);

    if total > viewport {
        let mut state = ScrollbarState::new(total).position(top);
        let sb = Scrollbar::new(ScrollbarOrientation::VerticalRight)
            .begin_symbol(None)
            .end_symbol(None);
        f.render_stateful_widget(sb, timeline_area, &mut state);
    }
    
    // Рисуем прогресс-бар всей очереди под таймлайном
    let (total_progress, _) = match &app.runner {
        RunnerStatus::Running { step_idx, started_at, .. } => {
            let mut total_duration = 0.0;
            let mut current_duration = 0.0;

            for (i, step) in app.queue.iter().enumerate() {
                let duration = match step {
                    Step::Run { .. } => app.time_test_s as f64,
                    Step::Pause { seconds, .. } => *seconds as f64,
                    Step::Teardown { .. } => 5.0, // Примерное время
                };
                total_duration += duration;
                if i < *step_idx {
                    current_duration += duration;
                } else if i == *step_idx {
                    // Добавляем часть текущего шага
                    let elapsed = started_at.elapsed().as_secs_f64();
                    current_duration += elapsed.min(duration);
                }
            }
            
            let ratio = if total_duration > 0.0 { current_duration / total_duration } else { 0.0 };
            (ratio, format!("Общий прогресс: {:.0}%", ratio * 100.0))
        }
        _ => (0.0, "Ожидание...".to_string()),
    };
    
    f.render_widget(BrailleBar::new(total_progress, 1.0).fill_color(theme::ACCENT), progress_area);
}
