# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::DefaultConfig;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw($default_config);
our $default_config = {
    provisioning        => 100,
    provis_step         => 5,
    length              => 8,
    always_encrypt      => 0,
    anti_flood_delay    => 5,
    max_file_size       => 10*1024*1024,
    https               => 0,
    proposed_delays     => '0,1,7,30,365',
    default_delay       => 0,
    max_delay           => 0,
    token_length        => 24,
    crypto_key_length   => 8,
    thumbnail_size      => 100,
    watermark_path      => '',
    watermark_placement => 'SouthEast',
    watermark_default   => 'none',
    watermark_enforce   => 'none',
    theme               => 'default',
    disable_api         => 0,
    upload_dir          => 'files',
    dbtype              => 'sqlite',
    db_path             => 'lutim.db',
    max_files_in_zip    => 15,
    prefix              => '/',
    minion              => {
        enabled => 0,
        dbtype  => 'sqlite',
        db_path => 'minion.db'
    },
    session_duration       => 3600,
    cache_max_size         => 0,
    memcached_servers      => [],
    quiet_logs             => 0,
    disable_img_stats      => 0,
    x_frame_options        => 'DENY',
    x_content_type_options => 'nosniff',
    x_xss_protection       => '1; mode=block',
    stats_day_num          => 365,
    keep_ip_during         => 365,
    policy_when_full       => 'warn',
};

1;
