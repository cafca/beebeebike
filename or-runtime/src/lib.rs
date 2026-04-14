/// Placeholder async helper to prove crate wiring.
/// Later milestones can replace this with a real runtime abstraction.
pub async fn run_async<T>(value: T) -> T {
    value
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn run_async_typechecks() {
        // This is a compile-time wiring test; we don't execute the async fn here.
        let _future = run_async(42);
        let _future = run_async("ok");
    }
}
