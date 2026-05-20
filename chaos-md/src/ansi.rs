//! Парсер байтов PTY → ratatui Lines.
//!
//! CRLF (\r\n): обычная строка — flush в историю.
//! Голый \r без последующего \n: тикер, перезаписывает current_line.

use ansi_to_tui::IntoText;
use ratatui::text::Line;

pub struct LogParser {
    current: Vec<u8>,
    cr_pending: bool,
}

impl Default for LogParser {
    fn default() -> Self {
        Self { current: Vec::new(), cr_pending: false }
    }
}

pub struct LogUpdate {
    pub new_lines: Vec<Line<'static>>,
    pub current_line: Option<String>,
}

impl LogParser {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn feed(&mut self, bytes: &[u8]) -> LogUpdate {
        let mut new_lines = Vec::new();
        for &b in bytes {
            if b == b'\n' {
                // CRLF или просто LF — flush строки в историю
                let raw = std::mem::take(&mut self.current);
                self.cr_pending = false;
                let s = String::from_utf8_lossy(&raw).into_owned();
                if !s.trim().is_empty() {
                    new_lines.push(parse_ansi_line(&s));
                }
            } else if b == b'\r' {
                // Запомним; решение принимаем когда увидим следующий байт
                self.cr_pending = true;
            } else {
                if self.cr_pending {
                    // Голый \r — тикер, сбрасываем буфер без записи в историю
                    self.current.clear();
                    self.cr_pending = false;
                }
                self.current.push(b);
            }
        }
        let current_line = if self.current.is_empty() {
            None
        } else {
            Some(String::from_utf8_lossy(&self.current).replace('\r', ""))
        };
        LogUpdate { new_lines, current_line }
    }
}

pub fn parse_ansi_line(s: &str) -> Line<'static> {
    let s = s.replace('\r', "");
    s.as_bytes()
        .into_text()
        .ok()
        .and_then(|t| t.lines.into_iter().next())
        .unwrap_or_else(|| Line::raw(s))
}
