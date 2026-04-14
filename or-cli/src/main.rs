use or_domain::greet;

fn main() {
    // Trivial CLI demonstrating crate inter-dependencies.
    // Later milestones can extend this into a more featureful tool.
    let name = std::env::args().nth(1).unwrap_or_else(|| "CLI".to_string());
    let message = greet(&name);
    println!("{}", message);
}

#[cfg(test)]
mod tests {
    // Basic smoke test to ensure the binary compiles and main is callable.
    // Integration tests can be added later if needed.
    #[test]
    fn binary_compiles() {
        assert_eq!(2 + 2, 4);
    }
}
