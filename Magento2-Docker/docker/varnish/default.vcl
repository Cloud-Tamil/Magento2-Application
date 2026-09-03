vcl 4.1;

backend default {

    .host = "nginx";

    .port = "80";

    .first_byte_timeout = 600s;

    .between_bytes_timeout = 60s;

}

sub vcl_recv {

    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE") {

        return (pipe);

    }

    if (req.method != "GET" && req.method != "HEAD") {

        return (pass);

    }

    if (req.http.Authorization) {

        return (pass);

    }

    if (req.http.Cookie ~ "PHPSESSID") {

        return (pass);

    }

    if (req.url ~ "^/(checkout|customer|wishlist|catalogsearch)") {

        return (pass);

    }

    return (hash);

}

sub vcl_backend_response {

    if (beresp.status >= 400) {

        set beresp.ttl = 0s;

        set beresp.uncacheable = true;

        return (deliver);

    }

    set beresp.grace = 3d;

    return (deliver);

}
