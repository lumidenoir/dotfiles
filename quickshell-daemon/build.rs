fn main() {
    println!("cargo:rustc-link-lib=pulse-simple");
    println!("cargo:rustc-link-lib=pulse");
    println!("cargo:rustc-link-lib=fftw3");
    println!("cargo:rustc-link-lib=m");
}

