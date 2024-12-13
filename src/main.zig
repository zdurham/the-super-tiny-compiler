const std = @import("std");
const mem = std.mem;

const TokenType = enum { lparen, rparen, number, string, name, whitespace, illegal };

const Token = struct { type: TokenType, value: []const u8 };

fn isLetter(ch: u8) bool {
    return std.ascii.isAlphabetic(ch) or ch == '_';
}

fn isDigit(ch: u8) bool {
    return std.ascii.isDigit(ch);
}

pub fn tokenizer(allocator: mem.Allocator, input: []const u8) ![]Token {
    var current: u32 = 0;
    var tokens = std.ArrayList(Token).init(allocator);
    // defer tokens.deinit();
    while (current < input.len) {
        const char = input[current];
        const token = switch (char) {
            '(' => Token{ .type = TokenType.lparen, .value = "(" },
            ')' => Token{ .type = TokenType.rparen, .value = ")" },
            '0'...'9' => blk: {
                const start = current;
                var end = current;
                while (isDigit(input[end])) {
                    end += 1;
                }
                current = end - 1;
                break :blk Token{
                    .type = TokenType.number,
                    .value = input[start..end],
                };
            },
            'a'...'z', 'A'...'Z' => blk: {
                const start = current;
                var end = current;
                while (isLetter(input[end])) {
                    end += 1;
                }
                current = end - 1;
                break :blk Token{ .type = TokenType.name, .value = input[start..end] };
            },
            '"' => blk: {
                // skip first "
                current += 1;
                const start = current;
                var end = current;
                while (input[end] != '"') {
                    end += 1;
                }
                // skip final "
                const string = input[start..end];
                end += 1;
                // fix this part later... (because I do current += 1)
                current = end - 1;
                break :blk Token{ .type = TokenType.string, .value = string };
            },
            ' ' => Token{ .type = TokenType.whitespace, .value = "" },
            else => Token{ .type = TokenType.illegal, .value = "" },
        };
        if (token.type != TokenType.illegal and token.type != TokenType.whitespace) {
            std.log.info("Token before appending: {s} ", .{token.value});
            try tokens.append(token);
        }
        current += 1;
    }
    return tokens.toOwnedSlice();
}

const Node = union(enum) {
    program: Program,
    literal: Literal,
    callExpression: CallExpression,
};

pub const LiteralType = enum {
    number,
    string,
};

pub const Literal = struct { value: []const u8, type: LiteralType };

pub const CallExpression = struct { name: []const u8, params: []Node };

pub const Program = struct { body: []Node };

pub const Parser = struct {
    const Self = @This();
    current: u8 = 0,
    program: Program,
    tokens: []Token,
    pub fn init(tokens: []Token) void {
        return Self{ .current = 0, .tokens = tokens };
    }

    pub fn parse(self: *Self) []Node {
        const body = std.ArrayList(Node).init(std.heap.page_allocator);
        while (self.current < self.tokens.len) {
            body.append(self.walk());
        }
        return .{.program{ .body = body.toOwnedSlice() }};
    }

    pub fn walk(
        self: *Self,
    ) Node {
        var token = self.tokens[self.current];
        switch (token.type) {
            TokenType.lparen => blk: {
                const params = std.ArrayList(Node).init(std.heap.page_allocator);

                // bypass first parenthesis token (
                // since we don't need to record it as a node
                self.current += 1;
                token = self.tokens[self.current];
                const name = token.value;
                while (token.type != TokenType.rparen) {
                    try params.append(self.walk());
                }
                // skip closing parenthesis now
                self.current += 1;
                break :blk Node{ .callExpression = CallExpression{
                    .name = name,
                    .params = params.toOwnedSlice(),
                } };
            },
            TokenType.number | TokenType.string => blk: {
                self.current += 1;
                const literalType = if (token.type == TokenType.string) LiteralType.string else LiteralType.number;
                break :blk Node{ .literal = Literal{ .value = token.value, .type = literalType } };
            },
        }
    }
};

pub fn main() !void {
    const input = "add(12 34) (123) \"ok\"   (1)(5678) \"ok\"";
    const allocator = std.heap.page_allocator;
    const tokens = tokenizer(allocator, input) catch |err| {
        std.debug.print("something bad happened: {any}", .{err});
        return;
    };
    defer allocator.free(tokens);
}

test "tokenizer" {
    const input = "(add 12 34)";
    const expectedTokens = [_]Token{
        Token{ .type = TokenType.lparen, .value = "(" },
        Token{ .type = TokenType.name, .value = "add" },
        Token{ .type = TokenType.number, .value = "12" },
        Token{ .type = TokenType.number, .value = "34" },
        Token{ .type = TokenType.rparen, .value = ")" },
    };
    const allocator = std.heap.page_allocator;
    const tokens = tokenizer(allocator, input) catch |err| {
        std.debug.print("something bad happened: {any}", .{err});
        return;
    };
    defer allocator.free(tokens);
    try std.testing.expectEqualDeep(expectedTokens[0..], tokens);
}
