//! Диалоговое окно Check (-C).
//!
//! Оранжевый фон, рамка, заголовок, прокручиваемый текст с переносом строк.
//! Закрывается по Esc или 'c'.

use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Clear, Paragraph, Wrap};
use ratatui::Frame;

use crate::app::App;
use crate::theme;

const BG: Color = Color::Rgb(160, 72, 0);
const FG: Color = Color::Rgb(255, 240, 200);

pub fn draw(f: &mut Frame, app: &App) {
    let Some(dlg) = &app.check_dialog else {
        return;
    };

    let area = centered_rect(78, 82, f.area());
    f.render_widget(Clear, area);

    let marker = Span::styled("◆", Style::default().fg(theme::DIALOG_MARKER));
    let title_span = Span::styled(
        if dlg.loading {
            format!(" {} — загрузка… ", dlg.title)
        } else {
            format!(" {} ", dlg.title)
        },
        Style::default().fg(theme::DIALOG_TITLE).add_modifier(Modifier::BOLD),
    );

    let block = Block::default()
        .title(Line::from(vec![marker, title_span]))
        .title_bottom(Line::from(Span::styled(
            " Esc · c — закрыть   ↑ ↓ · PgUp · PgDn — скролл ",
            Style::default().fg(theme::DIALOG_BORDER),
        )))
        .borders(Borders::ALL)
        .border_style(Style::default().fg(theme::DIALOG_BORDER))
        .style(Style::default().bg(BG));

    let inner = block.inner(area);
    f.render_widget(block, area);

    let lines: Vec<Line> = dlg
        .lines
        .iter()
        .map(|s| Line::from(Span::styled(s.clone(), Style::default().fg(FG))))
        .collect();

    let p = Paragraph::new(lines)
        .wrap(Wrap { trim: false })
        .scroll((dlg.scroll as u16, 0))
        .style(Style::default().bg(BG).fg(FG));
    f.render_widget(p, inner);
}

fn centered_rect(percent_x: u16, percent_y: u16, r: Rect) -> Rect {
    let vert = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(r);
    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(vert[1])[1]
}
