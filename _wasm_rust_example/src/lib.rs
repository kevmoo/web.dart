mod bindings {
    wit_bindgen::generate!({
        path: "wit/world.wit",
    });

    use super::AdderComponent;
    export!(AdderComponent);
}

struct AdderComponent;

impl bindings::exports::docs::adder::add::Guest for AdderComponent {
    fn add(x: u64, y: u64) -> u64 {
        x + y
    }

    fn greet(name: String) -> String {
        format!("Hello, {}!", name)
    }
}
