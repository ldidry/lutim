requires 'Mojolicious', '>= 7.31';
requires 'EV';
requires 'IO::Socket::SSL';
requires 'Net::SSLeay', '>= 1.81';
requires 'Data::Validate::URI';
requires 'Net::Domain::TLD', '>= 1.75'; # Must have the last version to handle (at least) .xyz and .link
requires 'Mojolicious::Plugin::I18N';
requires 'Mojolicious::Plugin::DebugDumperHelper';
requires 'Mojolicious::Plugin::StaticCache';
requires 'Mojolicious::Plugin::GzipStatic';
requires 'Mojolicious::Plugin::CSPHeader';
requires 'Text::Unidecode';
requires 'DateTime';
requires 'Filesys::DiskUsage';
requires 'Switch';
requires 'Crypt::CBC';
requires 'Crypt::Blowfish';
requires 'Locale::Maketext';
requires 'Locale::Maketext::Extract';
requires 'File::MimeInfo';
requires 'IO::Scalar';
requires 'Image::ExifTool';
requires 'Data::Entropy';
requires 'List::MoreUtils', '> 0.33';
requires 'Archive::Zip';
requires 'ISO::639_1';

feature 'postgresql', 'PostgreSQL support' => sub {
    requires 'Mojo::Pg';
    requires 'Mojolicious::Plugin::PgURLHelper';
};
feature 'sqlite', 'SQLite support' => sub {
    requires 'Mojo::SQLite', '>= 3.000';
    requires 'Minion::Backend::SQLite', '>= 4.001';
};
feature 'minion', 'Minion support' => sub {
    requires 'Minion';
};
feature 'cache', 'Cache system' => sub {
    requires 'Mojolicious::Plugin::CHI';
    requires 'Data::Serializer';
};
feature 'memcached', 'Cache system using Memcached' => sub {
    requires 'Mojolicious::Plugin::CHI';
    requires 'CHI::Driver::Memcached';
    requires 'Cache::Memcached';
};
feature 'ldap', 'LDAP authentication support' => sub {
    requires 'Net::LDAP';
    requires 'Mojolicious::Plugin::Authentication';
};
feature 'htpasswd', 'Htpasswd authentication support' => sub {
    requires 'Apache::Htpasswd';
    requires 'Mojolicious::Plugin::Authentication';
};
feature 'test' => sub {
    requires 'Devel::Cover';
};
