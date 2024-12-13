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

pub const CallExpression = struct { name: []const u8, params: []const Node };

pub const Program = struct { body: []const Node };

pub const Parser = struct {
    const Self = @This();
    current: u8 = 0,
    tokens: []Token,
    pub fn init(tokens: []Token) Self {
        return Self{ .current = 0, .tokens = tokens };
    }

    pub fn parse(self: *Self) !Node {
        var body = std.ArrayList(Node).init(std.heap.page_allocator);
        errdefer body.deinit();
        while (self.current < self.tokens.len) {
            const expression = self.walk() catch {
                break;
            };
            try body.append(expression);
        }
        return .{
            .program = Program{
                .body = try body.toOwnedSlice(),
                // .body = &[_]Node{},
            },
        };
    }

    pub fn walk(
        self: *Self,
    ) !Node {
        var token = self.tokens[self.current];

        const expression = switch (token.type) {
            TokenType.lparen => blk: {
                var params = std.ArrayList(Node).init(std.heap.page_allocator);
                errdefer params.deinit();

                // bypass first parenthesis token (
                // since we don't need to record it as a node
                self.current += 1;
                token = self.tokens[self.current];
                const name = token.value;
                self.current += 1;
                token = self.tokens[self.current];
                while (token.type != TokenType.rparen) {
                    const expression = self.walk() catch {
                        break;
                    };
                    try params.append(expression);
                    token = self.tokens[self.current];
                }
                // skip closing parenthesis now
                self.current += 1;
                break :blk Node{
                    .callExpression = CallExpression{
                        .name = name,
                        .params = try params.toOwnedSlice(),
                    },
                };
            },
            TokenType.number, TokenType.string => blk: {
                self.current += 1;
                const literalType = if (token.type == TokenType.string) LiteralType.string else LiteralType.number;
                break :blk Node{ .literal = Literal{ .value = token.value, .type = literalType } };
            },
            else => error.Oops,
        };
        return expression;
    }
};

pub fn main() !void {
    const input = "(add 1 (subtract 5 2))";
    const allocator = std.heap.page_allocator;
    const tokens = tokenizer(allocator, input) catch |err| {
        std.log.err("Tokenizer blew up: {any}", .{err});
        return;
    };
    defer allocator.free(tokens);
    var parser = Parser.init(tokens);
    const ast = try parser.parse();
    std.log.info("{any}", .{ast.program.body[0].callExpression.params});
    std.log.debug("{}", .{@TypeOf(ast.program.body)});
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

test "parser" {
    const input = "(add 1 (subtract5 2))";

    var start: usize = 0;
    _ = &start;
    const subtractParams = [_]Node{
        Node{ .literal = Literal{ .type = LiteralType.number, .value = "5" } },
        Node{
            .literal = Literal{ .type = LiteralType.number, .value = "2" },
        },
    };
    //
    const addParams = [_]Node{
        Node{
            .literal = Literal{ .type = LiteralType.number, .value = "1" },
        },
        Node{
            .callExpression = CallExpression{
                .name = "subtract",
                .params = subtractParams[start..],
            },
        },
    };
    const body = [_]Node{
        Node{
            .callExpression = CallExpression{
                .name = "add",
                .params = addParams[start..],
            },
        },
    };

    const expectedProgram = Node{
        .program = Program{ .body = body[start..] },
    };
    const allocator = std.heap.page_allocator;
    const tokens = tokenizer(allocator, input) catch |err| {
        std.debug.print("something bad happened: {any}", .{err});
        return;
    };
    defer allocator.free(tokens);
    var parser = Parser.init(tokens);
    const ast = try parser.parse();
    try std.testing.expectEqualDeep(expectedProgram, ast);
}
