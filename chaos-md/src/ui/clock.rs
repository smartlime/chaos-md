//! Большие ASCII-часы HH:MM:SS — встроенный 5-строчный блочный шрифт.

use chrono::{Local, Timelike};
use ratatui::layout::Rect;
use ratatui::style::Style;
use ratatui::text::{Line, Span};
use ratatui::widgets::Paragraph;
use ratatui::Frame;

use crate::app::{App, RunnerStatus};
use crate::queue::Step;

pub fn draw(f: &mut Frame, app: &App, area: Rect) {
    let millis = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .subsec_millis();

    let (time_text, color, show_time, blink_fast) = match &app.runner {
        RunnerStatus::Running { step_idx, started_at, .. } => {
            let step = app.queue.get(*step_idx);
            let is_pause = matches!(step, Some(Step::Pause { .. }));
            let is_teardown = matches!(step, Some(Step::Teardown { .. }));

            if is_teardown {
                ("--:--".to_string(), ratatui::style::Color::Rgb(80, 80, 80), true, false)
            } else {
                let start = app.chaos_started_at.unwrap_or(*started_at);
                let elapsed = start.elapsed().as_secs() as u32;
                let total_duration = if let Some(s) = step {
                    match s {
                        Step::Run { .. } => app.time_test_s,
                        Step::Pause { seconds, .. } => *seconds,
                        Step::Teardown { .. } => 5,
                    }
                } else { 0 };

                let remaining = total_duration.saturating_sub(elapsed);
                let minutes = remaining / 60;
                let seconds = remaining % 60;

                let color = if is_pause {
                    ratatui::style::Color::Rgb(0, 200, 100)
                } else {
                    ratatui::style::Color::Rgb(200, 0, 0)
                };

                (format!("{:02}:{:02}", minutes, seconds), color, true, !is_pause)
            }
        }
        RunnerStatus::Finished { .. } => {
            let now = Local::now();
            (format!("{:02}:{:02}", now.hour(), now.minute()), ratatui::style::Color::Rgb(100, 100, 100), true, false)
        }
        RunnerStatus::Idle => {
            let now = Local::now();
            (format!("{:02}:{:02}", now.hour(), now.minute()), ratatui::style::Color::Rgb(80, 80, 80), true, false)
        }
    };

    // Моргание двоеточия: blink_fast=2Гц, blink_slow=1Гц
    let colon_visible = if blink_fast {
        millis < 250 || (millis >= 500 && millis < 750)  // 2 Гц
    } else if matches!(&app.runner, RunnerStatus::Running { .. }) {
        millis < 500  // 1 Гц
    } else {
        true
    };
    let time_text = time_text.replace(':', if colon_visible { ":" } else { " " });

    let _ = show_time;
    {
        let rows = render_big(&time_text);
        let style = Style::default().fg(color);
        let lines: Vec<Line> = rows
            .into_iter()
            .map(|r| Line::from(Span::styled(r, style)))
            .collect();
        let p = Paragraph::new(lines).alignment(ratatui::layout::Alignment::Center);

        let shifted_area = Rect {
            x: area.x + 1,
            y: area.y,
            width: area.width.saturating_sub(1),
            height: area.height,
        };
        f.render_widget(p, shifted_area);
    }
}

fn render_big(s: &str) -> Vec<String> {
    let mut rows = vec![String::new(); 5];
    for ch in s.chars() {
        let glyph = glyph(ch);
        for (i, line) in glyph.iter().enumerate() {
            rows[i].push_str(line);
            rows[i].push(' ');
        }
    }
    rows
}

fn glyph(ch: char) -> [&'static str; 5] {
    match ch {
        '0' => ["███", "█ █", "█ █", "█ █", "███"],
        '1' => ["  █", "  █", "  █", "  █", "  █"],
        '2' => ["███", "  █", "███", "█  ", "███"],
        '3' => ["███", "  █", "███", "  █", "███"],
        '4' => ["█ █", "█ █", "███", "  █", "  █"],
        '5' => ["███", "█  ", "███", "  █", "███"],
        '6' => ["███", "█  ", "███", "█ █", "███"],
        '7' => ["███", "  █", "  █", "  █", "  █"],
        '8' => ["███", "█ █", "███", "█ █", "███"],
        '9' => ["███", "█ █", "███", "  █", "███"],
        ':' => ["   ", " █ ", "   ", " █ ", "   "],
        _   => ["   ", "   ", "   ", "   ", "   "],
    }
}
