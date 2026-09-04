vcl 4.1;

import std;


# ==========================================================
# BACKEND
# ==========================================================

backend default {

    .host = "nginx";

    .port = "80";

    .first_byte_timeout = 600s;

    .between_bytes_timeout = 600s;

    .connect_timeout = 60s;

    .probe = {

        .url = "/health-check";

        .timeout = 2s;

        .interval = 5s;

        .window = 10;

        .threshold = 5;
    }
}


# ==========================================================
# PURGE ACL
# ==========================================================

acl purge {

    "127.0.0.1";

    "localhost";
}


# ==========================================================
# RECEIVE REQUEST
# ==========================================================

sub vcl_recv {

    # ------------------------------------------------------
    # Restart handling
    # ------------------------------------------------------

    if (req.restarts > 0) {

        set req.hash_always_miss = true;
    }


    # ------------------------------------------------------
    # PURGE
    # ------------------------------------------------------

    if (req.method == "PURGE") {

        if (client.ip !~ purge) {

            return (synth(405, "Method not allowed"));
        }

        if (!req.http.X-Magento-Tags-Pattern &&
            !req.http.X-Pool) {

            return (
                synth(
                    400,
                    "X-Magento-Tags-Pattern or X-Pool required"
                )
            );
        }

        if (req.http.X-Magento-Tags-Pattern) {

            ban(
                "obj.http.X-Magento-Tags ~ " +
                req.http.X-Magento-Tags-Pattern
            );
        }

        if (req.http.X-Pool) {

            ban(
                "obj.http.X-Pool ~ " +
                req.http.X-Pool
            );
        }

        return (synth(200, "Purged"));
    }


    # ------------------------------------------------------
    # Unsupported methods
    # ------------------------------------------------------

    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE") {

        return (pipe);
    }


    # ------------------------------------------------------
    # Only GET/HEAD are cacheable
    # ------------------------------------------------------

    if (req.method != "GET" &&
        req.method != "HEAD") {

        return (pass);
    }


    # ------------------------------------------------------
    # Health endpoint
    # ------------------------------------------------------

    if (req.url ~ "^/health-check$") {

        return (pass);
    }


    # ------------------------------------------------------
    # Customer
    # ------------------------------------------------------

    if (req.url ~ "^/customer") {

        return (pass);
    }


    # ------------------------------------------------------
    # Checkout
    # ------------------------------------------------------

    if (req.url ~ "^/checkout") {

        return (pass);
    }


    # ------------------------------------------------------
    # Cart
    # ------------------------------------------------------

    if (req.url ~ "^/cart") {

        return (pass);
    }


    # ------------------------------------------------------
    # Wishlist
    # ------------------------------------------------------

    if (req.url ~ "^/wishlist") {

        return (pass);
    }


    # ------------------------------------------------------
    # Compare
    # ------------------------------------------------------

    if (req.url ~ "^/catalog/product_compare") {

        return (pass);
    }


    # ------------------------------------------------------
    # GraphQL authenticated requests
    # ------------------------------------------------------

    if (req.url ~ "/graphql" &&
        req.http.Authorization ~ "^Bearer" &&
        !req.http.X-Magento-Cache-Id) {

        return (pass);
    }


    # ------------------------------------------------------
    # Normalize URL
    # ------------------------------------------------------

    set req.url = regsub(
        req.url,
        "^http[s]?://",
        ""
    );


    # ------------------------------------------------------
    # Remove marketing parameters
    # ------------------------------------------------------

    if (
        req.url ~
        "(\?|&)(utm_[a-z]+|gclid|fbclid|dclid|msclkid|gbraid|wbraid)="
    ) {

        set req.url = regsuball(
            req.url,
            "(utm_[a-z]+|gclid|fbclid|dclid|msclkid|gbraid|wbraid)=[-_A-Za-z0-9+()%.]+&?",
            ""
        );

        set req.url = regsub(
            req.url,
            "[?|&]+$",
            ""
        );
    }


    # ------------------------------------------------------
    # Static/media
    # ------------------------------------------------------

    if (
        req.url ~ "^/(pub/)?(media|static)/"
    ) {

        return (pass);
    }


    # ------------------------------------------------------
    # Magento cookies
    # ------------------------------------------------------

    if (req.http.Cookie) {

        if (
            req.http.Cookie ~
            "PHPSESSID|private_content_version|private_content_version"
        ) {

            return (pass);
        }

        std.collect(req.http.Cookie);
    }


    # ------------------------------------------------------
    # Magento vary cookie
    # ------------------------------------------------------

    if (
        req.http.Cookie ~ "X-Magento-Vary="
    ) {

        set req.http.X-Magento-Vary =
            regsub(
                req.http.Cookie,
                "^.*?X-Magento-Vary=([^;]+);*.*$",
                "\1"
            );
    }


    return (hash);
}


# ==========================================================
# HASH
# ==========================================================

sub vcl_hash {

    if (
        req.http.X-Magento-Vary
    ) {

        hash_data(req.http.X-Magento-Vary);
    }


    if (
        req.http.X-Forwarded-Proto
    ) {

        hash_data(req.http.X-Forwarded-Proto);
    }


    if (
        req.url ~ "/graphql"
    ) {

        if (
            req.http.X-Magento-Cache-Id
        ) {

            hash_data(
                req.http.X-Magento-Cache-Id
            );
        }

        if (
            req.http.Store
        ) {

            hash_data(
                req.http.Store
            );
        }

        if (
            req.http.Content-Currency
        ) {

            hash_data(
                req.http.Content-Currency
            );
        }
    }
}


# ==========================================================
# BACKEND RESPONSE
# ==========================================================

sub vcl_backend_response {

    # ------------------------------------------------------
    # Grace period
    # ------------------------------------------------------

    set beresp.grace = 3d;


    # ------------------------------------------------------
    # ESI
    # ------------------------------------------------------

    if (
        beresp.http.content-type ~ "text"
    ) {

        set beresp.do_esi = true;
    }


    # ------------------------------------------------------
    # Compression
    # ------------------------------------------------------

    if (
        bereq.url ~ "\.js$" ||
        beresp.http.content-type ~ "text"
    ) {

        set beresp.do_gzip = true;
    }


    # ------------------------------------------------------
    # Magento debug
    # ------------------------------------------------------

    if (
        beresp.http.X-Magento-Debug
    ) {

        set beresp.http.X-Magento-Cache-Control =
            beresp.http.Cache-Control;
    }


    # ------------------------------------------------------
    # Don't cache private responses
    # ------------------------------------------------------

    if (
        beresp.status != 200 &&
        beresp.status != 404
    ) {

        set beresp.uncacheable = true;

        set beresp.ttl = 120s;

        return (deliver);
    }


    if (
        beresp.http.Cache-Control ~ "private"
    ) {

        set beresp.uncacheable = true;

        set beresp.ttl = 120s;

        return (deliver);
    }


    # ------------------------------------------------------
    # Set-cookie handling
    # ------------------------------------------------------

    if (
        beresp.ttl > 0s &&
        (bereq.method == "GET" ||
         bereq.method == "HEAD")
    ) {

        if (
            beresp.http.set-cookie
        ) {

            std.collect(
                beresp.http.set-cookie
            );
        }


        if (
            bereq.http.Cookie !~ "X-Magento-Vary=" &&
            beresp.http.set-cookie ~ "X-Magento-Vary="
        ) {

            set beresp.ttl = 0s;

            set beresp.uncacheable = true;
        }


        unset beresp.http.set-cookie;
    }


    # ------------------------------------------------------
    # Hit-for-pass
    # ------------------------------------------------------

    if (
        beresp.ttl <= 0s ||
        beresp.http.Surrogate-Control ~ "no-store" ||
        (
            !beresp.http.Surrogate-Control &&
            beresp.http.Cache-Control ~ "no-cache|no-store"
        ) ||
        beresp.http.Vary == "*"
    ) {

        set beresp.ttl = 120s;

        set beresp.uncacheable = true;
    }


    return (deliver);
}


# ==========================================================
# DELIVER
# ==========================================================

sub vcl_deliver {

    if (obj.uncacheable) {

        set resp.http.X-Magento-Cache-Debug =
            "UNCACHEABLE";

    } else if (obj.hits) {

        set resp.http.X-Magento-Cache-Debug =
            "HIT";

    } else {

        set resp.http.X-Magento-Cache-Debug =
            "MISS";
    }


    # ------------------------------------------------------
    # Don't expose internal headers
    # ------------------------------------------------------

    unset resp.http.X-Magento-Tags;

    unset resp.http.X-Powered-By;

    unset resp.http.X-Varnish;

    unset resp.http.Via;

    unset resp.http.Link;
}


# ==========================================================
# HIT
# ==========================================================

sub vcl_hit {

    if (
        obj.ttl >= 0s
    ) {

        return (deliver);
    }


    if (
        std.healthy(req.backend_hint)
    ) {

        if (
            obj.ttl + 300s > 0s
        ) {

            return (deliver);

        } else {

            return (restart);
        }

    } else {

        return (deliver);
    }
}
