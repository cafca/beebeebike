//! FFI-facing crate.
//! UniFFI integration and echo functions live here.

use std::time::Duration;

use or_domain::greet;

/// Simple function re-exported for FFI-bound callers to test wiring.
pub fn ffi_greet(name: &str) -> String {
    greet(name)
}

/// Synchronous echo function exposed via UniFFI.
pub fn sync_echo(input: String) -> String {
    input
}

/// Asynchronous echo with a configurable delay in milliseconds.
///
/// This is implemented using `async-std` so that UniFFI callers can
/// drive it via whatever executor they choose on the foreign side.
pub async fn delayed_echo(input: String, delay_ms: u32) -> String {
    async_std::task::sleep(Duration::from_millis(delay_ms as u64)).await;
    input
}

uniffi::include_scaffolding!("or_ffi");

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ffi_greet_delegates_to_domain() {
        assert_eq!(ffi_greet("Tester"), "Hello, Tester!");
    }

    #[test]
    fn sync_echo_returns_input() {
        let input = "echo me".to_string();
        let out = sync_echo(input.clone());
        assert_eq!(out, input);
    }

    #[test]
    fn delayed_echo_waits_and_returns_input() {
        let input = "delayed".to_string();
        let delay_ms = 10u32;
        let out = async_std::task::block_on(delayed_echo(input.clone(), delay_ms));
        assert_eq!(out, input);
    }
}
