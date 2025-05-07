use rand::Rng;
use std::env;
use std::error::Error;
use std::net::TcpListener;
use std::path::Path;
use std::process::Command;
use std::{thread, time::Duration};
use tauri::path::BaseDirectory;
use tauri::Manager;
use url::Url;

fn get_available_port() -> Result<u16, Box<dyn Error>> {
    // Port 0 tells the OS to assign an available ephemeral port.
    let listener = TcpListener::bind("0.0.0.0:0")?;

    let addr = listener.local_addr()?;

    // We don't need the listener anymore, so close it.
    drop(listener);

    Ok(addr.port())
}

fn generate_secret_key(length: usize) -> String {
    const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    let mut rng = rand::rng();
    let random_string: String = (0..length)
        .map(|_| {
            let idx = rng.random_range(0..CHARSET.len());
            CHARSET[idx] as char
        })
        .collect();
    random_string
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() -> Result<(), Box<dyn Error>> {
    tauri::Builder::default()
        .setup(|app| {
            let base_dir = app.path().app_data_dir()?; //
            let webserver_path = app
                .path()
                .resolve("binaries/webserver", BaseDirectory::Resource)?;
            let database_path = base_dir.join(Path::new("melocoton.db"));

            env::set_var("DATABASE_PATH", database_path);

            env::set_var("SECRET_KEY_BASE", generate_secret_key(64));
            env::set_var("PHX_SERVER", "1");
            env::set_var("PHX_HOST", "localhost");
            let port = get_available_port()?;

            println!("Running web application on port: {}", port);

            env::set_var("PORT", port.to_string());

            // start web server
            Command::new(webserver_path).spawn()?;
            // we need to wait a little bit for web server start
            thread::sleep(Duration::from_millis(300));

            let webview = app.get_webview_window("main").unwrap();
            let raw_url = format!("http://localhost:{}", port);
            let url = Url::parse(&raw_url)?;

            let _ = webview.navigate(url);

            #[cfg(desktop)]
            {
                use tauri_plugin_global_shortcut::{
                    Code, GlobalShortcutExt, Modifiers, Shortcut, ShortcutState,
                };

                let ctrl_n_shortcut = Shortcut::new(Some(Modifiers::META), Code::KeyN);
                app.handle().plugin(
                    tauri_plugin_global_shortcut::Builder::new()
                        .with_handler(move |another_app, shortcut, event| {
                            if shortcut == &ctrl_n_shortcut {
                                match event.state() {
                                    ShortcutState::Pressed => {
                                        let _webview_window = tauri::WebviewWindowBuilder::new(
                                            another_app,
                                            // we need to have a
                                            // unique application
                                            // label so we use a
                                            // random string
                                            generate_secret_key(10),
                                            tauri::WebviewUrl::App((&raw_url).into()),
                                        )
                                        .build()
                                        .unwrap();
                                    }
                                    ShortcutState::Released => {}
                                }
                            }
                        })
                        .build(),
                )?;

                app.global_shortcut().register(ctrl_n_shortcut)?;
            }

            Ok(())
        })
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");

    Ok(())
}
