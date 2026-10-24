const std = @import("std");
const posix = std.posix;

pub const ResourceError = error{ ProcessFdQuotaExceeded, SystemFdQuotaExceeded, SystemResources };
pub const Unexpected = posix.UnexpectedError;

pub const SocketError = ResourceError || error{AccessDenied} || Unexpected;
pub const BindError = error{ AccessDenied, AddressNotAvailable, AddressInUse, AlreadyBound } || Unexpected;
pub const ListenError = error{AccessDenied} || Unexpected;
pub const AcceptError = ResourceError || error{ConnectionAborted} || Unexpected;
pub const WriteError = ResourceError || error{ BrokenPipe, ConnectionResetByPeer } || Unexpected;

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
