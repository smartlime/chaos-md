use std::fs;
use std::path::PathBuf;

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::app::App;
use crate::queue::Phases;

#[derive(Serialize, Deserialize)]
pub struct SavedState {
    pub selected: Vec<bool>,
    pub phases_node: bool,
    pub phases_dc: bool,
    pub phases_dc_alt: bool,
    pub dry_run: bool,
    pub time_test_s: u32,
    pub time_wait_s: u32,
}

pub fn state_file(repo_root: &PathBuf) -> PathBuf {
    repo_root.join(".chaos-md-state.json")
}

pub fn save(app: &App) -> Result<()> {
    let state = SavedState {
        selected: app.selected.clone(),
        phases_node: app.phases.node,
        phases_dc: app.phases.dc,
        phases_dc_alt: app.phases.dc_alt,
        dry_run: app.dry_run,
        time_test_s: app.time_test_s,
        time_wait_s: app.time_wait_s,
    };
    let json = serde_json::to_string_pretty(&state)?;
    fs::write(state_file(&app.repo_root), json)?;
    Ok(())
}

pub fn load(repo_root: &PathBuf, app: &mut App) -> Result<()> {
    let path = state_file(repo_root);
    if !path.exists() {
        return Ok(());
    }
    let json = fs::read_to_string(path)?;
    let state: SavedState = serde_json::from_str(&json)?;

    if state.selected.len() == app.selected.len() {
        app.selected = state.selected;
    }
    app.phases = Phases {
        node: state.phases_node,
        dc: state.phases_dc,
        dc_alt: state.phases_dc_alt,
    };
    app.dry_run = state.dry_run;
    app.time_test_s = state.time_test_s;
    app.time_wait_s = state.time_wait_s;
    Ok(())
}
