use rand::Rng;
use std::env;
use std::error::Error;
use std::net::TcpListener;
use std::path::Path;
use std::process::Command;
use std::sync::Mutex;
use tauri::async_runtime::spawn;
use tauri::path::BaseDirectory;
use tauri::Manager;
use tauri::State;
use tokio::time::{sleep, Duration};
use url::Url;

struct AppData {
    port: u16,
}

#[tauri::command]
fn open_new_window(app_handle: tauri::AppHandle, state: State<'_, Mutex<AppData>>) {
    let port = state.lock().unwrap().port;
    let raw_url = format!("http://localhost:{}", port);

    let _webview_window = tauri::WebviewWindowBuilder::new(
        &app_handle,
        // we need to have a
        // unique application
        // label so we use a
        // random string
        generate_secret_key(10),
        tauri::WebviewUrl::App((raw_url).into()),
    )
    .build()
    .unwrap();
}

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
pub fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    tauri::Builder::default()
        .setup(|app| {
            let port = get_available_port()?;

            app.manage(Mutex::new(AppData { port: port }));

            println!("Running web application on port: {}", port);

            spawn(setup(app.handle().clone(), port));

            Ok(())
        })
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![open_new_window])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");

    Ok(())
}

async fn setup(
    app_handle: tauri::AppHandle,
    port: u16,
) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let base_dir = app_handle.path().app_data_dir()?;
    let webserver_path = app_handle
        .path()
        .resolve("binaries/webserver", BaseDirectory::Resource)?;
    let database_path = base_dir.join(Path::new("melocoton.db"));

    env::set_var("DATABASE_PATH", database_path);
    env::set_var("SECRET_KEY_BASE", generate_secret_key(64));
    env::set_var("PHX_SERVER", "1");
    env::set_var("PHX_HOST", "localhost");
    env::set_var("PORT", port.to_string());

    // start web server
    let _ = Command::new(webserver_path).spawn()?;

    // TODO: instead of having fixed wait time we should try to make a
    // request to check if the server is ready to receive requests
    sleep(Duration::from_secs(2)).await;

    let webview = app_handle.get_webview_window("main").unwrap();
    let raw_url = format!("http://localhost:{}", port);
    let url = Url::parse(&raw_url)?;

    let _ = webview.navigate(url);

    Ok(())
}
