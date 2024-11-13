const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const m = std.math;

const WIDTH = 300;
const HEIGHT = 300;

const CELL_SIZE = 2;

const SAND_COLOR = rl.Color.init(255, 255, 255, 255);
const EMPTY_COLOR = rl.Color.init(0, 0, 0, 255);

const FPS = 60;

const CellType = enum { Empty, Sand };

const Cell = struct {
    type: CellType,
    color: rl.Color,

    pub fn init() Cell {
        return Cell{
            .type = .Empty,
            .color = EMPTY_COLOR,
        };
    }

    pub fn empty(self: *Cell) bool {
        return self.type == .Empty;
    }

    pub fn clear(self: *Cell) void {
        self.type = .Empty;
        self.color = EMPTY_COLOR;
    }
};

const Simulation = struct {
    grid: [WIDTH][HEIGHT]Cell,
    rnd: std.Random.DefaultPrng,
    turn: bool,
    hue: f32,

    pub fn init() Simulation {
        return Simulation{
            .grid = [_][HEIGHT]Cell{[_]Cell{Cell.init()} ** HEIGHT} ** WIDTH,
            .rnd = std.Random.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp()))),
            .turn = false,
            .hue = 0.0,
        };
    }

    pub fn rand(self: *Simulation) u32 {
        return self.rnd.random().int(u32);
    }

    pub fn update(self: *Simulation) void {
        self.turn = !self.turn;
        var checked = [_][HEIGHT]bool{[_]bool{false} ** HEIGHT} ** WIDTH;

        for (0..WIDTH) |i| {
            for (0..HEIGHT) |j| {
                var x = i;
                const y = j;

                if (self.turn) {
                    x = WIDTH - 1 - x;
                }

                var cell = self.grid[x][y];
                const canGoDown = y != HEIGHT - 1;
                const canGoLeft = x != 0;
                const canGoRight = x != WIDTH - 1;

                if (cell.empty() or checked[x][y]) continue;

                if (canGoDown) {
                    if (self.grid[x][y + 1].empty()) {
                        self.grid[x][y + 1] = cell;
                        self.grid[x][y].clear();
                        checked[x][y] = true;
                        checked[x][y + 1] = true;
                        continue;
                    }
                    if (canGoLeft and canGoRight) {
                        if (self.grid[x + 1][y + 1].empty() and self.grid[x - 1][y + 1].empty()) {
                            const random = @mod(self.rand(), 2);
                            if (random == 0) {
                                self.grid[x + 1][y + 1] = cell;
                                checked[x + 1][y + 1] = true;
                            } else {
                                self.grid[x - 1][y + 1] = cell;
                                checked[x - 1][y + 1] = true;
                            }
                            self.grid[x][y].clear();
                            checked[x][y] = true;
                            continue;
                        }
                    }
                    if (canGoLeft) {
                        if (self.grid[x - 1][y + 1].empty()) {
                            self.grid[x - 1][y + 1] = cell;
                            self.grid[x][y].clear();
                            checked[x][y] = true;
                            checked[x - 1][y + 1] = true;
                            continue;
                        }
                    }
                    if (canGoRight) {
                        if (self.grid[x + 1][y + 1].empty()) {
                            self.grid[x + 1][y + 1] = cell;
                            self.grid[x][y].clear();
                            checked[x][y] = true;
                            checked[x + 1][y + 1] = true;
                            continue;
                        }
                    }
                }
            }
        }
    }

    pub fn set(self: *Simulation, x: usize, y: usize, cell: CellType) void {
        self.grid[x][y].type = cell;

        // hsv to rgb
        const h = self.hue;
        const s: f32 = 1.0;
        const v: f32 = 0.7;

        var r: f32 = 0.0;
        var g: f32 = 0.0;
        var b: f32 = 0.0;

        var _i: f32 = 0.0;
        var _f: f32 = 0.0;
        var _p: f32 = 0.0;
        var _q: f32 = 0.0;
        var _t: f32 = 0.0;

        _i = @floor(h * 6.0);
        _f = h * 6 - _i;
        _p = v * (1 - s);
        _q = v * (1 - _f * s);
        _t = v * (1 - (1 - _f) * s);
        switch (@mod(@as(i32, @intFromFloat(_i)), 6)) {
            0 => {
                r = v;
                g = _t;
                b = _p;
            },
            1 => {
                r = _q;
                g = v;
                b = _p;
            },
            2 => {
                r = _p;
                g = v;
                b = _t;
            },
            3 => {
                r = _p;
                g = _q;
                b = v;
            },
            4 => {
                r = _t;
                g = _p;
                b = v;
            },
            5 => {
                r = v;
                g = _p;
                b = _q;
            },
            else => {},
        }

        const colorR: u8 = @intFromFloat(r * 255.0);
        const colorG: u8 = @intFromFloat(g * 255.0);
        const colorB: u8 = @intFromFloat(b * 255.0);

        self.grid[x][y].color = rl.Color.init(colorR, colorG, colorB, 255);
    }

    pub fn clear(self: *Simulation, x: usize, y: usize) void {
        self.grid[x][y].clear();
    }

    pub fn draw(self: *Simulation) void {
        for (0..WIDTH) |x| {
            for (0..HEIGHT) |y| {
                const cell = self.grid[x][y];
                const color = cell.color;
                const xPos = @as(i32, @intCast(x * CELL_SIZE));
                const yPos = @as(i32, @intCast(y * CELL_SIZE));
                rl.drawRectangle(xPos, yPos, CELL_SIZE, CELL_SIZE, color);
            }
        }
    }
};

pub fn main() anyerror!void {
    var sim = Simulation.init();
    var mouse = rl.getMousePosition();

    rl.initWindow(WIDTH * CELL_SIZE, HEIGHT * CELL_SIZE, "sandbox");
    defer rl.closeWindow();

    rl.setTargetFPS(FPS);
    rg.guiSetIconScale(1);

    var leftMouseDown = false;
    var rightMouseDown = false;
    var clickedUI = false;

    var sliderInitValue: f32 = 5;
    const DRAW_RADIUS: *f32 = &sliderInitValue;

    var time: f32 = 0;
    while (!rl.windowShouldClose()) {
        time += rl.getFrameTime();

        if (time >= 1 / FPS) {
            time = 0;

            const RADIUS: usize = @intFromFloat(DRAW_RADIUS.*);

            if (leftMouseDown or rightMouseDown) {
                const x: usize = @intFromFloat(@max(@min((WIDTH - 1) * CELL_SIZE, mouse.x), 0) / CELL_SIZE);
                const y: usize = @intFromFloat(@max(@min((HEIGHT - 1) * CELL_SIZE, mouse.y), 0) / CELL_SIZE);

                for (0..(RADIUS * 2)) |i| {
                    for (0..(RADIUS * 2)) |j| {
                        var xOffset: i32 = @intCast(i);
                        var yOffset: i32 = @intCast(j);
                        xOffset -= @intCast(RADIUS);
                        yOffset -= @intCast(RADIUS);

                        const dist = xOffset * xOffset + yOffset * yOffset;
                        if (dist < RADIUS * RADIUS) {
                            const xPos = @as(i32, @intCast(x)) + xOffset;
                            const yPos = @as(i32, @intCast(y)) + yOffset;
                            if (xPos >= 0 and xPos <= WIDTH - 1 and yPos >= 0 and yPos <= HEIGHT - 1) {
                                if (leftMouseDown) {
                                    sim.set(@intCast(xPos), @intCast(yPos), .Sand);
                                } else if (rightMouseDown) {
                                    sim.clear(@intCast(xPos), @intCast(yPos));
                                }
                            }
                        }
                    }
                }

                if (leftMouseDown) {
                    leftMouseDown = false;

                    sim.hue += 0.001;
                    if (sim.hue >= 1) {
                        sim.hue = 0.0;
                    }
                } else if (rightMouseDown) {
                    rightMouseDown = false;
                }
            }

            sim.update();
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(EMPTY_COLOR);
        sim.draw();

        if (rg.guiSlider(rl.Rectangle.init(0, 0, WIDTH * CELL_SIZE, 15), "", "", DRAW_RADIUS, 1, 31) > 0) {
            mouse = rl.getMousePosition();
            DRAW_RADIUS.* = @min(@max(mouse.x / (WIDTH * CELL_SIZE), 0), 1) * 30 + 1;
            clickedUI = true;
        }

        if (!clickedUI) {
            if (rl.isMouseButtonDown(.mouse_button_left)) {
                mouse = rl.getMousePosition();
                leftMouseDown = true;
            }

            if (rl.isMouseButtonDown(.mouse_button_right)) {
                mouse = rl.getMousePosition();
                rightMouseDown = true;
            }
        } else {
            clickedUI = false;
        }
    }
}
