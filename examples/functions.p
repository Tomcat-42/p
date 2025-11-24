fn greet() {
    print("Hello!");
}

fn add(a, b) {
    return a + b;
}

fn factorial(n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

greet();
let result = add(5, 3);
print(result);
print(factorial(5));
