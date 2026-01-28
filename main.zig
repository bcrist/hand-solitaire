const Suit = enum (u2) {
    spades = 0,
    diamonds = 1,
    clubs = 2,
    hearts = 3,
};

const Value = enum (u4) {
    _A = 1,
    _2 = 2,
    _3 = 3,
    _4 = 4,
    _5 = 5,
    _6 = 6,
    _7 = 7,
    _8 = 8,
    _9 = 9,
    _T = 10,
    _J = 11,
    _Q = 12,
    _K = 13,
};

const Card = enum (u8) {
    sA = 0x00 + 1,
    s2 = 0x00 + 2,
    s3 = 0x00 + 3,
    s4 = 0x00 + 4,
    s5 = 0x00 + 5,
    s6 = 0x00 + 6,
    s7 = 0x00 + 7,
    s8 = 0x00 + 8,
    s9 = 0x00 + 9,
    sT = 0x00 + 10,
    sJ = 0x00 + 11,
    sQ = 0x00 + 12,
    sK = 0x00 + 13,

    dA = 0x10 + 1,
    d2 = 0x10 + 2,
    d3 = 0x10 + 3,
    d4 = 0x10 + 4,
    d5 = 0x10 + 5,
    d6 = 0x10 + 6,
    d7 = 0x10 + 7,
    d8 = 0x10 + 8,
    d9 = 0x10 + 9,
    dT = 0x10 + 10,
    dJ = 0x10 + 11,
    dQ = 0x10 + 12,
    dK = 0x10 + 13,

    cA = 0x20 + 1,
    c2 = 0x20 + 2,
    c3 = 0x20 + 3,
    c4 = 0x20 + 4,
    c5 = 0x20 + 5,
    c6 = 0x20 + 6,
    c7 = 0x20 + 7,
    c8 = 0x20 + 8,
    c9 = 0x20 + 9,
    cT = 0x20 + 10,
    cJ = 0x20 + 11,
    cQ = 0x20 + 12,
    cK = 0x20 + 13,

    hA = 0x30 + 1,
    h2 = 0x30 + 2,
    h3 = 0x30 + 3,
    h4 = 0x30 + 4,
    h5 = 0x30 + 5,
    h6 = 0x30 + 6,
    h7 = 0x30 + 7,
    h8 = 0x30 + 8,
    h9 = 0x30 + 9,
    hT = 0x30 + 10,
    hJ = 0x30 + 11,
    hQ = 0x30 + 12,
    hK = 0x30 + 13,

    pub fn init(s: Suit, v: Value) Card {
        return @enumFromInt(@as(u8, @intFromEnum(s)) * 0x10 + @intFromEnum(v));
    }

    pub fn suit(self: Card) Suit {
        return @enumFromInt(@intFromEnum(self) >> 4);
    }

    pub fn value(self: Card) Value {
        return @enumFromInt(@intFromEnum(self) & 0xF);
    }
};

fn shuffle(cards: []Card, rnd: std.Random) void {
    if (cards.len == 0) return;
    var end = cards.len - 1;
    while (end > 0) : (end -= 1) {
        const selected = rnd.intRangeAtMost(usize, 0, end);
        const temp = cards[selected];
        cards[selected] = cards[end];
        cards[end] = temp;
    }
}

const default_deck: [52]Card = d: {
    var deck: [52]Card = undefined;
    var i = 0;
    for (std.enums.values(Suit)) |s| {
        for (std.enums.values(Value)) |v| {
            deck[i] = .init(s, v);
            i += 1;
        }
    }
    break :d deck;
};

fn check_for_discards(stack: *std.ArrayList(Card), discards: *std.ArrayList(Card), summary: *Iteration_Summary, out: *std.io.Writer) !bool {
    if (stack.items.len < 4) return false;

    _ = out;

    const c1 = stack.items[stack.items.len - 1];
    const c4 = stack.items[stack.items.len - 4];

    if (c1.value() == c4.value()) {
        // try out.print("{t} matches value with {t}\n", .{ c1, c4 });
        discards.appendSliceAssumeCapacity(stack.items[stack.items.len - 4 ..][0..4]);
        stack.items.len -= 4;
        summary.value_matches += 1;
        return false;
    }

    if (c1.suit() == c4.suit()) {
        // try out.print("{t} matches suit with {t}\n", .{ c1, c4 });
        discards.appendSliceAssumeCapacity(stack.items[stack.items.len - 3 ..][0..2]);
        stack.items[stack.items.len - 3] = c1;
        stack.items.len -= 2;
        summary.suit_matches += 1;
        return true;
    }

    return false;
}

fn reveal_card(draw: *std.ArrayList(Card), stack: *std.ArrayList(Card)) bool {
    if (draw.pop()) |card| {
        stack.appendAssumeCapacity(card);
        return true;
    }
    return false;
}

fn rotate_card(stack: *std.ArrayList(Card)) void {
    if (stack.items.len < 2) return;
    const card = stack.orderedRemove(0);
    stack.appendAssumeCapacity(card);
}

const Iteration_Summary = struct {
    value_matches: usize,
    suit_matches: usize,
};

fn solve_iteration(draw: *std.ArrayList(Card), stack: *std.ArrayList(Card), discards: *std.ArrayList(Card), out: *std.io.Writer) !Iteration_Summary {
    var summary: Iteration_Summary = .{
        .value_matches = 0,
        .suit_matches = 0,
    };

    while (reveal_card(draw, stack)) {
        while (try check_for_discards(stack, discards, &summary, out)) {}
    }

    for (0..3) |_| {
        rotate_card(stack);
        while (try check_for_discards(stack, discards, &summary, out)) {}
    }

    return summary;
}

fn solve(draw: *std.ArrayList(Card), stack: *std.ArrayList(Card), discards: *std.ArrayList(Card), histogram: []usize, rnd: std.Random, out: *std.io.Writer) !void {
    std.debug.assert(draw.items.len == 52);
    std.debug.assert(stack.items.len == 0);
    std.debug.assert(discards.items.len == 0);

    var iterations: usize = 0;
    while (true) {
        const summary = try solve_iteration(draw, stack, discards, out);
        iterations += 1;
        const won = stack.items.len == 0;
        _ = summary;
        // try out.print("Iteration {}: {} value matches, {} suit matches, {} remaining cards{s}\n", .{
        //     iterations,
        //     summary.value_matches,
        //     summary.suit_matches,
        //     stack.items.len,
        //     if (won) "\t WIN!" else "",
        // });
        if (won) {
            if (iterations < histogram.len) {
                histogram[iterations] += 1;
            } else {
                try out.print("Won after {} iterations\n", .{ iterations });
            }
            break;
        } else if (iterations > 1000000) {
            try out.print("Giving up after {} iterations\n", .{ iterations });
            break;
        }
        shuffle(stack.items, rnd);
        const temp = draw.*;
        draw.* = stack.*;
        stack.* = temp;
        draw.appendSliceAssumeCapacity(discards.items);
        discards.clearRetainingCapacity();
        std.debug.assert(stack.items.len == 0);
    }
}


pub fn main() !void {
    var draw_buf: [52]Card = undefined;
    var draw: std.ArrayList(Card) = .initBuffer(&draw_buf);

    var stack_buf: [52]Card = undefined;
    var stack: std.ArrayList(Card) = .initBuffer(&stack_buf);

    var discards_buf: [52]Card = undefined;
    var discards: std.ArrayList(Card) = .initBuffer(&discards_buf);

    var rng: std.Random.Xoshiro256 = .init(std.crypto.random.int(u64));

    var stdout_buf: [64]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdout_buf);

    var histogram: [1000]usize = @splat(0);

    for (0..1000_000) |_| {
        draw.clearRetainingCapacity();
        stack.clearRetainingCapacity();
        discards.clearRetainingCapacity();
        draw.appendSliceAssumeCapacity(&default_deck);
        shuffle(draw.items, rng.random());
        try solve(&draw, &stack, &discards, &histogram, rng.random(), &stdout.interface);
        try stdout.interface.flush();
    }

    for (0.., histogram) |i, count| {
        if (count == 0)  continue;
        try stdout.interface.print("{}\t{}\n", .{ i, count });
        try stdout.interface.flush();
    }
}

const std = @import("std");
