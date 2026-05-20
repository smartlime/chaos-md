//! Диалог конфигурации — параметры окружения и приложения.

use std::env;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Clear, Paragraph};
use ratatui::Frame;

use crate::app::App;
use crate::catalog::CATALOG;
use crate::theme;

pub fn draw(f: &mut Frame, app: &App) {
    if !app.config_dialog_open {
        return;
    }

    let area = centered_rect(76, 90, f.area());
    f.render_widget(Clear, area);

    let marker = Span::styled(" ◆", Style::default().fg(theme::DIALOG_MARKER));
    let title_span = Span::styled(
        " Configuration ",
        Style::default().fg(theme::CONFIG_TITLE).add_modifier(Modifier::BOLD),
    );

    let block = Block::default()
        .title(Line::from(vec![marker, title_span]))
        .title_bottom(Line::from(Span::styled(
            " Esc · o — закрыть ",
            Style::default().fg(theme::CONFIG_BORDER),
        )))
        .borders(Borders::ALL)
        .border_style(Style::default().fg(theme::CONFIG_BORDER))
        .style(Style::default().bg(theme::CONFIG_BG));

    let inner = block.inner(area);
    f.render_widget(block, area);

    let mut lines: Vec<Line> = Vec::new();

    // Добавляем пустую строку сверху для отступа
    lines.push(Line::raw(""));

    // Параметры приложения
    lines.push(format_row("Repo root", app.repo_root.display().to_string().as_str()));
    lines.push(format_row("Time -t", &format!("{}s", app.time_test_s)));
    lines.push(format_row("Wait pause", &format!("{}s", app.time_wait_s)));

    let node_mark = if app.phases.node { "✓" } else { " " };
    lines.push(format_row("Phase node", node_mark));

    let dc_mark = if app.phases.dc { "✓" } else { " " };
    lines.push(format_row("Phase dc", dc_mark));

    let count = app.selected.iter().filter(|&&x| x).count();
    let total = CATALOG.len();
    lines.push(format_row("Tests selected", &format!("{} / {}", count, total)));

    let dry_mark = if app.dry_run { "Yes" } else { "No" };
    lines.push(format_row("Dry-run", dry_mark));

    // Пусто между разделами
    lines.push(Line::raw(""));

    // Переменные окружения
    lines.push(format_row("SINGLE_HOST", &env_or_dash("SINGLE_HOST")));
    lines.push(format_row("DC_HOSTS", &env_or_dash("DC_HOSTS")));
    lines.push(format_row("NET_IFACE", &env_or_dash("NET_IFACE")));
    lines.push(format_row("DEFAULT_NET_DELAY", &env_or_dash("DEFAULT_NET_DELAY")));
    lines.push(format_row("DEFAULT_NET_LOSS", &env_or_dash("DEFAULT_NET_LOSS")));
    lines.push(format_row("DEFAULT_BW_RATE", &env_or_dash("DEFAULT_BW_RATE")));
    lines.push(format_row("YDB_PORTS", &env_or_dash("YDB_PORTS")));
    lines.push(format_row("YDBD_STORAGE_SERVICE", &env_or_dash("YDBD_STORAGE_SERVICE")));
    lines.push(format_row("YDBD_TENANT_SERVICES", &env_or_dash("YDBD_TENANT_SERVICES")));
    lines.push(format_row("YDBD_TENANT_UNIT_GLOB", &env_or_dash("YDBD_TENANT_UNIT_GLOB")));
    lines.push(format_row("DEFAULT_MEM_PERCENT", &env_or_dash("DEFAULT_MEM_PERCENT")));
    lines.push(format_row("DEFAULT_MEM_RATE", &env_or_dash("DEFAULT_MEM_RATE")));
    lines.push(format_row("DEFAULT_DISK_DEVICE", &env_or_dash("DEFAULT_DISK_DEVICE")));
    lines.push(format_row("DEFAULT_YDBD_BIN", &env_or_dash("DEFAULT_YDBD_BIN")));
    lines.push(format_row("SSH_OPTS", &env_or_dash("SSH_OPTS")));
    lines.push(format_row("GRAFANA_URL", &env_or_dash("GRAFANA_URL")));
    lines.push(format_row("GRAFANA_TOKEN", &env_or_dash("GRAFANA_TOKEN")));

    let p = Paragraph::new(lines)
        .style(Style::default().bg(theme::CONFIG_BG).fg(theme::CONFIG_FG));

    // Смещение на 1 символ вправо
    let inner_offset = Rect {
        x: inner.x + 1,
        y: inner.y,
        width: inner.width.saturating_sub(2),
        height: inner.height,
    };

    f.render_widget(p, inner_offset);
}

fn env_or_dash(key: &str) -> String {
    env::var(key).unwrap_or_else(|_| "—".to_string())
}

fn format_row(key: &str, value: &str) -> Line<'static> {
    Line::from(vec![
        Span::styled(
            format!("{:<25}", key),
            Style::default().fg(theme::CONFIG_FG),
        ),
        Span::styled(
            "║ ",
            Style::default().fg(theme::CONFIG_BORDER),
        ),
        Span::styled(
            truncate_value(value, 40),
            Style::default().fg(theme::CONFIG_FG),
        ),
    ])
}

fn truncate_value(s: &str, max: usize) -> String {
    if s.len() > max {
        format!("{}…", &s[..max - 1])
    } else {
        s.to_string()
    }
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
