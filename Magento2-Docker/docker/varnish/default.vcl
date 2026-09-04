vcl 4.1;

backend default {
    .host = "nginx";
    .port = "80";
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 60s;
}

sub vcl_recv {
    # --------------------------------------------------------
    # Only supported HTTP methods
    # --------------------------------------------------------
    if (
        req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE"
    ) {
        return (pipe);
    }

    # --------------------------------------------------------
    # Do not cache non GET/HEAD
    # --------------------------------------------------------
    if (
        req.method != "GET" &&
        req.method != "HEAD"
    ) {
        return (pass);
    }

    # --------------------------------------------------------
    # Authorization
    # --------------------------------------------------------
    if (req.http.Authorization) {
        return (pass);
    }

    # --------------------------------------------------------
    # Magento sessions
    # --------------------------------------------------------
    if (
        req.http.Cookie ~ "PHPSESSID"
    ) {
        return (pass);
    }

    # --------------------------------------------------------
    # Magento dynamic pages
    # --------------------------------------------------------
    if (
        req.url ~ "^/(checkout|customer|wishlist)"
    ) {
        return (pass);
    }

    # --------------------------------------------------------
    # Search
    # --------------------------------------------------------
    if (
        req.url ~ "^/catalogsearch"
    ) {
        return (pass);
    }

    return (hash);
}

sub vcl_backend_response {
    # --------------------------------------------------------
    # Never cache errors
    # --------------------------------------------------------
    if (beresp.status >= 400) {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
        return (deliver);
    }

    # --------------------------------------------------------
    # Grace period
    # --------------------------------------------------------
    set beresp.grace = 3d;

    return (deliver);
}
