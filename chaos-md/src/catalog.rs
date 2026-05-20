//! Каталог хаос-тестов. Хардкод: 12 записей, стабильно.

use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Scope {
    Node,
    Dc,
    DcAlt,
}

impl Scope {
    /// Флаг для bash-теста: -1 / -4 / -A.
    pub fn flag(self) -> &'static str {
        match self {
            Scope::Node => "-1",
            Scope::Dc => "-4",
            Scope::DcAlt => "-A",
        }
    }
    pub fn label(self) -> &'static str {
        match self {
            Scope::Node => "node",
            Scope::Dc => "dc",
            Scope::DcAlt => "dc_alt",
        }
    }
}

impl fmt::Display for Scope {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.label())
    }
}

#[derive(Debug, Clone, Copy)]
pub struct TestEntry {
    pub id: &'static str,
    pub file: &'static str,
    pub title: &'static str,
    pub nemesis: &'static str,
    pub scopes: &'static [Scope],
    /// Нужен ли явный -D после прогона всех фаз (хаос «висит» — типично blade, tc).
    pub needs_teardown: bool,
}

pub const CATALOG: &[TestEntry] = &[
    TestEntry { id: "01", file: "01-cpu-load.sh",        title: "cpu load",      nemesis: "blade",    scopes: &[Scope::Node, Scope::Dc, Scope::DcAlt], needs_teardown: true  },
    TestEntry { id: "02", file: "02-mem-load.sh",        title: "mem load",      nemesis: "blade",    scopes: &[Scope::Node, Scope::Dc, Scope::DcAlt], needs_teardown: true  },
    TestEntry { id: "03", file: "03-disk-fail.sh",       title: "disk fail",     nemesis: "disk",     scopes: &[Scope::Node],                          needs_teardown: false },
    TestEntry { id: "04", file: "04-net-delay.sh",       title: "net delay",     nemesis: "tc",       scopes: &[Scope::Node, Scope::Dc],               needs_teardown: true  },
    TestEntry { id: "05", file: "05-net-loss.sh",        title: "net loss",      nemesis: "tc",       scopes: &[Scope::Node, Scope::Dc],               needs_teardown: true  },
    TestEntry { id: "06", file: "06-net-drop.sh",        title: "net drop",      nemesis: "iptables", scopes: &[Scope::Node],                          needs_teardown: false },
    TestEntry { id: "07", file: "07-net-bw.sh",          title: "net bw",        nemesis: "tc",       scopes: &[Scope::Node, Scope::Dc],               needs_teardown: true  },
    TestEntry { id: "08", file: "08-proc-freeze.sh",     title: "proc freeze",   nemesis: "proc",     scopes: &[Scope::Node],                          needs_teardown: false },
    TestEntry { id: "09", file: "09-proc-kill.sh",       title: "proc kill",     nemesis: "proc",     scopes: &[Scope::Node],                          needs_teardown: false },
    TestEntry { id: "10", file: "10-rolling-upgrade.sh", title: "rolling-up",    nemesis: "systemd",  scopes: &[Scope::Node],                          needs_teardown: false },
    TestEntry { id: "11", file: "11-dc-drop.sh",         title: "dc drop",       nemesis: "iptables", scopes: &[Scope::Dc],                            needs_teardown: false },
    TestEntry { id: "12", file: "12-server-stop.sh",     title: "server stop",   nemesis: "systemd",  scopes: &[Scope::Node, Scope::Dc, Scope::DcAlt], needs_teardown: false },
];

pub fn find_by_id(id: &str) -> Option<usize> {
    CATALOG.iter().position(|t| t.id == id)
}
