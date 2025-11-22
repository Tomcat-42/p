// Basic object examples

object Point {
    fn init(x, y) {
        this.x = x;
        this.y = y;
    }

    fn display() {
        print(this.x);
        print(this.y);
    }
}

object Counter {
    fn init() {
        this.count = 0;
    }

    fn increment() {
        this.count = this.count + 1;
    }

    fn get() {
        return this.count;
    }
}

let p = Point();
p.init(10, 20);
p.display();

let c = Counter();
c.init();
c.increment();
c.increment();
print(c.get());
