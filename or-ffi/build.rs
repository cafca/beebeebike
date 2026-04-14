fn main() {
    // Trigger UniFFI code generation as part of the build.
    // In later milestones, Swift binding generation will hook into this as well.
    println!("cargo:rerun-if-changed=src/or_ffi.udl");
    uniffi::generate_scaffolding("src/or_ffi.udl").expect("failed to generate UniFFI scaffolding");
}
