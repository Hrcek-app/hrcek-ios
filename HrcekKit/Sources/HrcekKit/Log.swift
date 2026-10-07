import os

/// Loggers for app and extension alike, under one subsystem so a single
/// `log stream` predicate shows both processes.
public enum Log {
    public static let subsystem = "app.hrcek"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let api = Logger(subsystem: subsystem, category: "api")
    public static let auth = Logger(subsystem: subsystem, category: "auth")
    public static let share = Logger(subsystem: subsystem, category: "share")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}
