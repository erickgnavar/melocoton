slint::include_modules!();

use rusqlite::{Connection, Result};

// enum ColumnValue {
//     String(String),
// }

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let ui = AppWindow::new()?;
    let conn = Connection::open_in_memory()?;

    _ = conn.execute(
        "CREATE TABLE person (
            id    INTEGER PRIMARY KEY,
            name  TEXT NOT NULL,
            surname  TEXT NOT NULL,
            age   integer not null  
        )",
        (), // empty list of parameters.
    );

    _ = conn.execute(
        "INSERT INTO person (name, age) VALUES (?1, ?2, ?3)",
        ("erick", "navarro", 33),
    );

    let mut stmt = conn.prepare("SELECT name, age FROM person")?;
    // let values = stmt.query_map([], |row| Ok(row.get::<_, String>(0)));

    // for value in values {
    //     println!("{:?}", value);
    // }
    for row in stmt.query_map([], |r| r.get::<_, String>(0))? {
        println!("{}", row?);
    }

    // ui.on_request_increase_value({
    //     let ui_handle = ui.as_weak();
    //     move || {
    //         let ui = ui_handle.unwrap();
    //         ui.set_counter(ui.get_counter() + 1);
    //     }
    // });

    ui.on_run_query(move |query| println!("query: {}", query.trim()));

    match ui.run() {
        Err(_e) => panic!("hello"),
        Ok(value) => Ok(value),
    }
}
