<?php
/**
 * Forces every mysqli connection *must* be encrypted.
 * This file is autoloaded via Composer (see composer.json).
 */
function mr_ssl_mysqli_connect(
    string $host,
    string $user,
    string $pass,
    string $db   = '',
    int    $port = 3306
): mysqli {

    $ca = getenv('MYSQLI_CLIENT_SSL_CA')
       ?: getenv('CONNECTION_SSL_CA')
       ?: '/etc/ssl/certs/ca-certificates.crt';

    $link = mysqli_init();
    $link->ssl_set(null, null, $ca, null, null);
    $ok = $link->real_connect(
        $host, $user, $pass, $db, $port,
        null, MYSQLI_CLIENT_SSL
    );
    if (!$ok) {
        throw new RuntimeException(
            "TLS connect failed ({$link->connect_errno}) {$link->connect_error}"
        );
    }
    return $link;
}