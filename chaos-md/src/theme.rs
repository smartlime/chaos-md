//! Цветовая палитра.

use ratatui::style::{Color, Modifier, Style};

pub const ACCENT: Color = Color::Rgb(0, 255, 255); // Cyber Cyan
pub const FOCUS: Color = Color::Rgb(0, 128, 128); // Dark Cyber Cyan for background
pub const FOCUS_FG: Color = Color::Rgb(0, 255, 255); // Bright Cyan for text on focus
pub const DIM: Color = Color::Rgb(80, 80, 80);
pub const OK: Color = Color::Rgb(0, 255, 128); // Cyber Green
pub const OK_DIM: Color = Color::Rgb(0, 64, 32); // Very dark green for inactive button
pub const ZONE_BORDER_INACTIVE: Color = Color::Rgb(0, 100, 80); // Dark green for inactive zone titles
pub const STATUS_BG_DARK: Color = Color::Rgb(20, 20, 30); // Very dark for YDB footer
pub const ERR: Color = Color::Rgb(255, 0, 128); // Cyber Pink/Red
pub const WARN_OR_DEFAULT: Color = Color::Rgb(255, 255, 0); // Cyber Yellow
pub const CYBER_GRAY: Color = Color::Rgb(40, 40, 40);

// Границы экранных зон (тусклые)
pub const ZONE_BORDER_FOCUSED: Color = Color::Rgb(0, 180, 180);
pub const ZONE_BORDER_IDLE: Color = Color::Rgb(100, 100, 100); // Сделали светлее

// Диалоговые окна (яркие)
pub const DIALOG_TITLE: Color = Color::Rgb(200, 160, 0);
pub const DIALOG_BORDER: Color = Color::Rgb(255, 255, 100);
pub const DIALOG_MARKER: Color = Color::White;

// Config dialog
pub const CONFIG_BG: Color = Color::Rgb(0, 120, 120);
pub const CONFIG_BORDER: Color = Color::Rgb(255, 255, 100);
pub const CONFIG_TITLE: Color = Color::Rgb(200, 160, 0);
pub const CONFIG_FG: Color = Color::Rgb(255, 240, 200);

pub fn block_title(focused: bool) -> Style {
    if focused {
        Style::default().fg(ACCENT).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(ZONE_BORDER_INACTIVE).add_modifier(Modifier::BOLD)
    }
}

pub fn block_border(focused: bool) -> Style {
    if focused {
        Style::default().fg(ZONE_BORDER_FOCUSED)
    } else {
        Style::default().fg(ZONE_BORDER_IDLE)
    }
}

pub fn dim() -> Style {
    Style::default().fg(DIM)
}
