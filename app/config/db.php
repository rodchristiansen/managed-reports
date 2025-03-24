<?php

$driver = env('CONNECTION_DRIVER', 'sqlite');

switch ($driver) {
    case 'sqlite':
        return [
            'driver'    => 'sqlite',
            'database'  => env('CONNECTION_DATABASE', APP_ROOT . 'app/db/db.sqlite'),
            'username'  => '',
            'password'  => '',
            'options'   => env('CONNECTION_OPTIONS', []),
        ];

    case 'mysql':
        return [
            'driver'    => 'mysql',
            'host'      => env('CONNECTION_HOST', '127.0.0.1'),
            'port'      => env('CONNECTION_PORT', 3306),
            'database'  => env('CONNECTION_DATABASE', 'munkireport'),
            'username'  => env('CONNECTION_USERNAME', 'munkireport'),
            'password'  => env('CONNECTION_PASSWORD', 'munkireport'),
            'charset'   => env('CONNECTION_CHARSET', 'utf8mb4'),
            'collation' => env('CONNECTION_COLLATION', 'utf8mb4_unicode_ci'),
            'strict'    => env('CONNECTION_STRICT', true),
            'engine'    => env('CONNECTION_ENGINE', 'InnoDB'),
            'ssl_enabled' => env('CONNECTION_SSL_ENABLED', true),
            'options'   => [
                PDO::MYSQL_ATTR_SSL_CA    => env('CONNECTION_SSL_CA'),
                PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => env('PDO_MYSQL_ATTR_SSL_VERIFY_SERVER_CERT', true),
                PDO::MYSQL_ATTR_SSL_KEY   => env('CONNECTION_SSL_KEY', null),
                PDO::MYSQL_ATTR_SSL_CERT  => env('CONNECTION_SSL_CERT', null),
            ],
        ];

    default:
        throw new \Exception(sprintf("Unknown driver: %s", $driver));
}
