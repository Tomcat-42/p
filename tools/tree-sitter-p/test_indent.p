// Test indentation and folding
fn fibonacci(n) {
let result = 0;
if (n <= 1) {
result = n;
} else {
let a = 0;
let b = 1;
for (let i = 2; i <= n; i = i + 1) {
let temp = a + b;
a = b;
b = temp;
}
result = b;
}
return result;
}

object Counter {
let count = 0;

fn increment() {
count = count + 1;
}

fn decrement() {
count = count - 1;
}

fn get() {
return count;
}
}

fn main() {
print fibonacci(10);
let counter = Counter();
counter.increment();
print counter.get();
}
