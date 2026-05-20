//! Слежение за logs/timeline.log: при изменении дочитываем новые строки и
//! отправляем их в основной runtime через mpsc.

use std::io::{Read, Seek, SeekFrom};
use std::path::PathBuf;

use anyhow::Result;
use chrono::{DateTime, Local};
use notify::{Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use tokio::sync::mpsc;

use crate::app::CurrentEvent;

/// Парсенное событие timeline.
#[derive(Debug, Clone)]
pub struct TimelineLine {
    pub kind: String, // CHAOS_START | CHAOS_END | CHAOS_CANCEL
    pub started_wall: Option<DateTime<Local>>,
    pub details: String,
}

impl TimelineLine {
    pub fn parse(line: &str) -> Option<Self> {
        // Формат: "YYYY-MM-DD HH:MM:SS TZ  KIND      details..."
        // (см. lib/timeline.sh::log_tl)
        let mut parts = line.splitn(5, ' ').filter(|s| !s.is_empty());
        let date = parts.next()?;
        let time = parts.next()?;
        let tz = parts.next()?;
        // Дальше может быть пробельный паддинг + KIND + details.
        // Используем splitn(5) — последний чанк это «KIND details», т.к. у нас padding.
        let rest = parts.next()?;
        let rest_more = parts.next().unwrap_or("");
        let combined = format!("{}{}{}", rest, if rest_more.is_empty() { "" } else { " " }, rest_more);
        let combined = combined.trim_start();

        let mut iter = combined.splitn(2, char::is_whitespace);
        let kind = iter.next()?.to_string();
        let details = iter.next().unwrap_or("").trim().to_string();

        let dt_str = format!("{date} {time} {tz}");
        let started_wall = chrono::DateTime::parse_from_str(&dt_str, "%Y-%m-%d %H:%M:%S %Z")
            .ok()
            .map(|d| d.with_timezone(&Local));

        Some(TimelineLine {
            kind,
            started_wall,
            details,
        })
    }

    /// Превратить детали `"net delay  scope=dc  hosts=4  delay=50ms  timeout=600s"`
    /// в CurrentEvent (только для CHAOS_START).
    pub fn to_current_event(&self) -> CurrentEvent {
        let mut ev = CurrentEvent {
            kind: self.kind.clone(),
            started_wall: self.started_wall,
            raw_details: self.details.clone(),
            timeout_s: None,
            scope: None,
            hosts: None,
        };
        for token in self.details.split_whitespace() {
            if let Some((k, v)) = token.split_once('=') {
                match k {
                    "timeout" => {
                        // Может быть "600s" — отбрасываем 's'
                        let v = v.trim_end_matches('s');
                        ev.timeout_s = v.parse().ok();
                    }
                    "scope" => ev.scope = Some(v.to_string()),
                    "hosts" => ev.hosts = v.parse().ok(),
                    _ => {}
                }
            }
        }
        ev
    }
}

#[derive(Debug)]
pub enum WatcherEvent {
    Line(TimelineLine),
}

/// Запустить watcher. Шлёт по строке за раз.
pub fn spawn(path: PathBuf, tx: mpsc::UnboundedSender<WatcherEvent>) -> Result<RecommendedWatcher> {
    // Если файла нет — он появится позже; следим за директорией.
    let parent = path.parent().map(|p| p.to_path_buf()).unwrap_or_default();
    std::fs::create_dir_all(&parent).ok();

    // Текущий offset в файле; первоначально — конец файла, чтобы не выгружать всю историю.
    let mut offset: u64 = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);

    let path_for_handler = path.clone();
    let tx_for_handler = tx.clone();

    let mut watcher = notify::recommended_watcher(move |res: notify::Result<Event>| {
        let Ok(event) = res else { return; };
        match event.kind {
            EventKind::Modify(_) | EventKind::Create(_) => {}
            _ => return,
        }
        if !event.paths.iter().any(|p| p == &path_for_handler) {
            return;
        }
        // Файл изменился — дочитать новые байты.
        if let Ok(mut f) = std::fs::File::open(&path_for_handler) {
            let len = f.metadata().map(|m| m.len()).unwrap_or(0);
            if len < offset {
                // Файл укоротили (rotate?) — начнём с нуля.
                offset = 0;
            }
            if f.seek(SeekFrom::Start(offset)).is_err() { return; }
            let mut buf = Vec::new();
            if f.read_to_end(&mut buf).is_ok() {
                offset += buf.len() as u64;
                let s = String::from_utf8_lossy(&buf);
                for line in s.split('\n') {
                    if line.is_empty() { continue; }
                    if let Some(parsed) = TimelineLine::parse(line) {
                        let _ = tx_for_handler.send(WatcherEvent::Line(parsed));
                    }
                }
            }
        }
    })?;

    watcher.watch(&parent, RecursiveMode::NonRecursive)?;
    Ok(watcher)
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_line_basic() {
        let line = "2026-05-04 12:34:56 MSK     CHAOS_START       net delay  scope=dc  hosts=4  delay=50ms  timeout=600s";
        let p = TimelineLine::parse(line).expect("parsed");
        assert_eq!(p.kind, "CHAOS_START");
        assert!(p.details.contains("net delay"));
        let ev = p.to_current_event();
        assert_eq!(ev.scope.as_deref(), Some("dc"));
        assert_eq!(ev.hosts, Some(4));
        assert_eq!(ev.timeout_s, Some(600));
    }
}
