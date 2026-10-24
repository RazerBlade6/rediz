const std = @import("std");
const posix = std.posix;

pub const ResourceError = error{ ProcessFdQuotaExceeded, SystemFdQuotaExceeded, SystemResources };
pub const Unexpected = posix.UnexpectedError;

pub const SocketError = ResourceError || error{AccessDenied} || Unexpected;
pub const BindError = error{ AccessDenied, AddressNotAvailable, AddressInUse, AlreadyBound } || Unexpected;
pub const ListenError = error{AccessDenied} || Unexpected;
pub const AcceptError = ResourceError || error{ConnectionAborted} || Unexpected;
pub const WriteError = error{ SystemResources, BrokenPipe, ConnectionResetByPeer } || Unexpected;

pub fn serverSocket() SocketError!posix.socket_t {
    const fd = std.c.socket(posix.AF.INET, posix.SOCK.STREAM, posix.IPPROTO.TCP);

    return switch (posix.errno(fd)) {
        .SUCCESS => fd,
        .MFILE => SocketError.ProcessFdQuotaExceeded,
        .NFILE => SocketError.SystemFdQuotaExceeded,
        .NOBUFS => SocketError.SystemResources,
        .NOMEM => SocketError.SystemResources,
        .ACCES => SocketError.AccessDenied,
        else => |err| posix.unexpectedErrno(err),
    };
}

pub fn bind(socket: posix.socket_t, sockaddr: *const posix.sockaddr, socklen: posix.socklen_t) BindError!void {
    const bound = posix.errno(std.c.bind(socket, sockaddr, socklen));

    return switch (bound) {
        .SUCCESS => {},
        .ACCES => BindError.AccessDenied,
        .ADDRNOTAVAIL => BindError.AddressNotAvailable,
        .ADDRINUSE => BindError.AddressInUse,
        .INVAL => BindError.AlreadyBound,
        else => |err| posix.unexpectedErrno(err),
    };
}

pub fn listen(
    socket: posix.socket_t,
) ListenError!void {
    const backlog: u32 = 64;
    const listening = std.c.listen(socket, backlog);

    return switch (posix.errno(listening)) {
        .SUCCESS => {},
        .ACCES => ListenError.AccessDenied,
        else => |err| posix.unexpectedErrno(err),
    };
}

pub fn accept(socket: posix.socket_t) AcceptError!posix.socket_t {
    const accepted = std.c.accept(socket, null, null);

    while (true) {
        switch (posix.errno(accepted)) {
            .SUCCESS => return accepted,
            .CONNABORTED => return AcceptError.ConnectionAborted,
            .MFILE => return AcceptError.ProcessFdQuotaExceeded,
            .NFILE => return AcceptError.SystemFdQuotaExceeded,
            .NOMEM => return AcceptError.SystemResources,
            .INTR => continue,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

pub fn write(socket: posix.socket_t, buf: []const u8) WriteError!isize {
    const written = std.c.write(socket, buf.ptr, buf.len);

    while (true) {
        switch (posix.errno(written)) {
            .SUCCESS => return written,
            .PIPE => return WriteError.BrokenPipe,
            .CONNRESET => return WriteError.ConnectionResetByPeer,
            .NOBUFS => return WriteError.SystemResources,
            .INTR => continue,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

pub fn close(socket: posix.socket_t) !void {
    const closed = posix.errno(std.c.close(socket));

    return switch (closed) {
        .SUCCESS => {},
        .BADF => unreachable,
        .IO => {},
        .INTR => {},
        else => |err| posix.unexpectedErrno(err),
    };
}

test {
    std.testing.refAllDecls(@This());
}
