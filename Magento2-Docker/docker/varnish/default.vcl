vcl 4.1;


# ============================================================
# BACKEND
# ============================================================

backend default {

    .host = "nginx";

    .port = "80";

    .first_byte_timeout = 600s;

    .between_bytes_timeout = 60s;

}


# ============================================================
# PURGE ACL
# ============================================================

acl purge {

    "localhost";

    "127.0.0.1";

}


# ============================================================
# REQUEST PROCESSING
# ============================================================

sub vcl_recv {


    # --------------------------------------------------------
    # PURGE
    # --------------------------------------------------------

    if (req.method == "PURGE") {

        if (client.ip !~ purge) {

            return (synth(405, "Not allowed"));

        }

        return (purge);

    }


    # --------------------------------------------------------
    # UNSUPPORTED METHODS
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
    # ONLY CACHE GET / HEAD
    # --------------------------------------------------------

    if (
        req.method != "GET" &&
        req.method != "HEAD"
    ) {

        return (pass);

    }


    # --------------------------------------------------------
    # AUTHENTICATED REQUESTS
    # --------------------------------------------------------

    if (req.http.Authorization) {

        return (pass);

    }


    # --------------------------------------------------------
    # SESSION / CUSTOMER COOKIES
    # --------------------------------------------------------

    if (
        req.http.Cookie ~ "PHPSESSID" ||
        req.http.Cookie ~ "private_content_version" ||
        req.http.Cookie ~ "section_data_ids" ||
        req.http.Cookie ~ "customer_auth"
    ) {

        return (pass);

    }


    # --------------------------------------------------------
    # DYNAMIC MAGENTO AREAS
    # --------------------------------------------------------

    if (
        req.url ~ "^/checkout" ||
        req.url ~ "^/customer" ||
        req.url ~ "^/wishlist" ||
        req.url ~ "^/catalogsearch"
    ) {

        return (pass);

    }


    # --------------------------------------------------------
    # CACHE
    # --------------------------------------------------------

    return (hash);

}


# ============================================================
# BACKEND RESPONSE
# ============================================================

sub vcl_backend_response {


    if (beresp.status >= 400) {

        set beresp.ttl = 0s;

        set beresp.uncacheable = true;

        return (deliver);

    }


    set beresp.grace = 3d;

    return (deliver);

}


# ============================================================
# RESPONSE
# ============================================================

sub vcl_deliver {


    if (obj.hits > 0) {

        set resp.http.X-Cache = "HIT";

    }

    else {

        set resp.http.X-Cache = "MISS";

    }

}
