# Logging Bro Output to Kafka

A Bro log writer that sends logging output to Kafka.  This provides a convenient means for tools in the Hadoop ecosystem, such as Storm, Spark, and others, to process the data generated by Bro.

This software is a part of the [Apache Metron](http://metron.apache.org/) project which integrates a variety of open source, big data technologies to offer a platform to detect and respond to cyber threats at-scale.

* [Installation](#installation)
* [Activation](#activation)
* [Settings](#settings)
* [Kerberos](#kerberos)
* [Contributing](#contributing)

## Installation

### `bro-pkg` Installation

`bro-pkg` is the preferred mechanism for installing this plugin, as it will dynamically retrieve, build, test, and load the plugin.  Note, that you will still need to [activate](#activation) and configure the plugin after your installation.

1. Install [librdkafka](https://github.com/edenhill/librdkafka), a native client library for Kafka.  This plugin has been tested against the latest release of librdkafka, which at the time of this writing is v0.11.5.

    In order to use this plugin within a kerberized Kafka environment, you will also need `libsasl2` installed and will need to pass `--enable-sasl` to the `configure` script.

    ```
    $ curl -L https://github.com/edenhill/librdkafka/archive/v0.11.5.tar.gz | tar xvz
    $ cd librdkafka-0.11.5/
    $ ./configure --enable-sasl
    $ make
    $ sudo make install
    ```

1. Configure `bro-pkg` by following the quickstart guide [here](https://bro-package-manager.readthedocs.io/en/stable/quickstart.html).

1. Install the plugin using `bro-pkg install`.

    ```
    $ bro-pkg install apache/metron-bro-plugin-kafka --version master
    The following packages will be INSTALLED:
      bro/apache/metron-bro-plugin-kafka (master)

    Verify the following REQUIRED external dependencies:
    (Ensure their installation on all relevant systems before proceeding):
      from bro/apache/metron-bro-plugin-kafka (master):
        librdkafka ~0.11.5

    Proceed? [Y/n]
    bro/apache/metron-bro-plugin-kafka asks for LIBRDKAFKA_ROOT (Path to librdkafka installation tree) ? [/usr/local/lib]
    Saved answers to config file: /home/jonzeolla/.bro-pkg/config
    Running unit tests for "bro/apache/metron-bro-plugin-kafka"
    all 10 tests successful


    Installing "bro/apache/metron-bro-plugin-kafka"........
    Installed "bro/apache/metron-bro-plugin-kafka" (master)
    Loaded "bro/apache/metron-bro-plugin-kafka"
    ```

1. Run the following command to ensure that the plugin was installed successfully.

    ```
    $ bro -N Apache::Kafka
    Apache::Kafka - Writes logs to Kafka (dynamic, version 0.3)
    ```

### Manual Installation

Manually installing the plugin should only occur in situations where installing and configuring `bro-pkg` is not reasonable, such as in a docker container.  If you are running bro in an environment where you do not have Internet connectivity, investigate [bundles](https://bro-package-manager.readthedocs.io/en/stable/bro-pkg.html#bundle) or creating an internal [package source](https://bro-package-manager.readthedocs.io/en/stable/source.html).

These instructions could also be helpful if you were interested in distributing this as a package (such as a deb or rpm).

1. Install [librdkafka](https://github.com/edenhill/librdkafka), a native client library for Kafka.  This plugin has been tested against the latest release of librdkafka, which at the time of this writing is v0.11.5.

    In order to use this plugin within a kerberized Kafka environment, you will also need `libsasl2` installed and will need to pass `--enable-sasl` to the `configure` script.

    ```
    $ curl -L https://github.com/edenhill/librdkafka/archive/v0.11.5.tar.gz | tar xvz
    $ cd librdkafka-0.11.5/
    $ ./configure --enable-sasl
    $ make
    $ sudo make install
    ```

1. Build the plugin using the following commands.

    ```
    $ ./configure --bro-dist=$BRO_SRC
    $ make
    $ sudo make install
    ```

1. Run the following command to ensure that the plugin was installed successfully.

    ```
    $ bro -N Apache::Kafka
    Apache::Kafka - Writes logs to Kafka (dynamic, version 0.3)
    ```

## Activation

The following examples highlight different ways that the plugin can be used.  Simply add the Bro script language to your `local.bro` file (for example, `/usr/share/bro/site/local.bro`) as shown to demonstrate the example.

### Example 1 - Send a list of logs to kafka

The goal in this example is to send all HTTP and DNS records to a Kafka topic named `bro`.
 * Any configuration value accepted by librdkafka can be added to the `kafka_conf` configuration table.  
 * The `topic_name` will default to send all records to a single Kafka topic called 'bro'.
 * Defining `logs_to_send` will send the HTTP and DNS records to the brokers specified in your `Kafka::kafka_conf`.
```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::logs_to_send = set(HTTP::LOG, DNS::LOG);
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "server1.example.com:9092,server2.example.com:9092"
);
```

### Example 2 - Send all active logs

This plugin has the ability send all active logs to the "bro" kafka topic with the following configuration.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::send_all_active_logs = T;
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "localhost:9092"
);
```

### Example 3 - Send all active logs with exclusions

You can also specify a blacklist of bro logs to ensure they aren't being sent to kafka regardless of the `Kafka::send_all_active_logs` and `Kafka::logs_to_send` configurations.  In this example, we will send all of the enabled logs except for the Conn log.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::send_all_active_logs = T;
redef Kafka::logs_to_exclude = set(Conn::LOG);
redef Kafka::topic_name = "bro";
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "localhost:9092"
);
```

### Example 4 - Send each bro log to a unique topic

It is also possible to send each log stream to a uniquely named topic.  The goal in this example is to send all HTTP records to a Kafka topic named `http` and all DNS records to a separate Kafka topic named `dns`.
 * The `topic_name` value must be set to an empty string.
 * The `$path` value of Bro's Log Writer mechanism is used to define the topic name.
 * Any configuration value accepted by librdkafka can be added to the `$config` configuration table.  
 * Each log writer accepts a separate configuration table.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::topic_name = "";
redef Kafka::tag_json = T;

event bro_init() &priority=-10
{
    # handles HTTP
    local http_filter: Log::Filter = [
        $name = "kafka-http",
        $writer = Log::WRITER_KAFKAWRITER,
        $config = table(
                ["metadata.broker.list"] = "localhost:9092"
        ),
        $path = "http"
    ];
    Log::add_filter(HTTP::LOG, http_filter);

    # handles DNS
    local dns_filter: Log::Filter = [
        $name = "kafka-dns",
        $writer = Log::WRITER_KAFKAWRITER,
        $config = table(
                ["metadata.broker.list"] = "localhost:9092"
        ),
        $path = "dns"
    ];
    Log::add_filter(DNS::LOG, dns_filter);
}
```

### Example 5 - Bro log filtering

You may want to configure bro to filter log messages with certain characteristics from being sent to your kafka topics.  For instance, Metron currently doesn't support IPv6 source or destination IPs in the default enrichments, so it may be helpful to filter those log messages from being sent to kafka (although there are [multiple ways](#notes) to approach this).  In this example we will do that that, and are assuming a somewhat standard bro kafka plugin configuration, such that:
 * All bro logs are sent to the default `bro` topic.
 * Each JSON message is tagged with the appropriate log type (such as `http`, `dns`, or `conn`), by setting `Kafka::tag_json` to true.
 * If the log message contains a 128 byte long source or destination IP address, the log is not sent to kafka.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::tag_json = T;

event bro_init() &priority=-10
{
    # handles HTTP
    Log::add_filter(HTTP::LOG, [
        $name = "kafka-http",
        $writer = Log::WRITER_KAFKAWRITER,
        $pred(rec: HTTP::Info) = { return ! (( |rec$id$orig_h| == 128 || |rec$id$resp_h| == 128 )); },
        $config = table(
            ["metadata.broker.list"] = "localhost:9092"
        )
    ]);

    # handles DNS
    Log::add_filter(DNS::LOG, [
        $name = "kafka-dns",
        $writer = Log::WRITER_KAFKAWRITER,
        $pred(rec: DNS::Info) = { return ! (( |rec$id$orig_h| == 128 || |rec$id$resp_h| == 128 )); },
        $config = table(
            ["metadata.broker.list"] = "localhost:9092"
        )
    ]);

    # handles Conn
    Log::add_filter(Conn::LOG, [
        $name = "kafka-conn",
        $writer = Log::WRITER_KAFKAWRITER,
        $pred(rec: Conn::Info) = { return ! (( |rec$id$orig_h| == 128 || |rec$id$resp_h| == 128 )); },
        $config = table(
            ["metadata.broker.list"] = "localhost:9092"
        )
    ]);
}
```

#### Notes
 * `logs_to_send` is mutually exclusive with `$pred`, thus for each log you want to set `$pred` on, you must individually setup a `Log::add_filter` and refrain from including that log in `logs_to_send`.
 * In Bro 2.5.x the bro project introduced a [logger function](https://www.bro.org/sphinx/cluster/index.html#logger) which removes the logging functions from the manager thread, and taking advantage of that is highly recommended.  If you are running this plugin on Bro 2.4.x, you may encounter issues where the manager thread is taking on too much responsibility and pinning a single CPU core without the ability to spread the load across additional cores.  In this case, it may be in your best interest to prefer using a bro logging predicate over filtering in your Metron cluster [using Stellar](https://github.com/apache/metron/tree/master/metron-stellar/stellar-common) in order to lessen the load of that thread.
 * You can also filter IPv6 logs from within your Metron cluster [using Stellar](https://github.com/apache/metron/tree/master/metron-stellar/stellar-common#is_ip).  In that case, you wouldn't apply a predicate in your bro configuration, and instead Stellar would filter the logs out before they were processed by the enrichment layer of Metron.
 * It is also possible to use the `is_v6_subnet()` bro function in your predicate, as of their [2.5 release](https://www.bro.org/sphinx-git/install/release-notes.html#bro-2-5), however the above example should work on [bro 2.4](https://www.bro.org/sphinx-git/install/release-notes.html#bro-2-4) and newer, which has been the focus of the kafka plugin.

### Example 6 - Sending a log to multiple topics

You are able to send a single bro log to multiple different kafka topics in the same kafka cluster by overriding the default topic (configured with `Kafka::topic_name`) by creating a custom bro `Log::Filter`.  In this example, the DHCP, RADIUS, and DNS logs are sent to the "bro" topic; the RADIUS log is duplicated to the "shew_bro_radius" topic; and the DHCP log is duplicated to the "shew_bro_dhcp" topic.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::logs_to_send = set(DHCP::LOG, RADIUS::LOG, DNS::LOG);
redef Kafka::topic_name = "bro";
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "server1.example.com:9092,server2.example.com:9092"
);
redef Kafka::tag_json = T;

event bro_init() &priority=-10
{
    # Send RADIUS to the shew_bro_radius topic
    local shew_radius_filter: Log::Filter = [
        $name = "kafka-radius-shew",
        $writer = Log::WRITER_KAFKAWRITER,
        $path = "shew_bro_radius"
        $config = table(["topic_name"] = "shew_bro_radius")
    ];
    Log::add_filter(RADIUS::LOG, shew_radius_filter);

    # Send DHCP to the shew_bro_dhcp topic
    local shew_dhcp_filter: Log::Filter = [
        $name = "kafka-dhcp-shew",
        $writer = Log::WRITER_KAFKAWRITER,
        $path = "shew_bro_dhcp"
        $config = table(["topic_name"] = "shew_bro_dhcp")
    ];
    Log::add_filter(DHCP::LOG, shew_dhcp_filter);
}
```

_Note_:  Because `Kafka::tag_json` is set to True in this example, the value of `$path` is used as the tag for each `Log::Filter`. If you were to add a log filter with the same `$path` as an existing filter, Bro will append "-N", where N is an integer starting at 2, to the end of the log path so that each filter has its own unique log path. For instance, the second instance of `conn` would become `conn-2`.

## Settings

### `logs_to_send`

A set of logs to send to kafka.

```
redef Kafka::logs_to_send = set(Conn::LOG, DHCP::LOG);
```

### `send_all_active_logs`

If true, all active logs will be sent to kafka other than those specified in
`logs_to_exclude`.

```
redef Kafka::send_all_active_logs = T;
```

### `logs_to_exclude`

A set of logs to exclude from being sent to kafka.

```
redef Kafka::logs_to_exclude = set(Conn::LOG, DNS::LOG);
```

### `topic_name`

The name of the topic in Kafka where all Bro logs will be sent to.

```
redef Kafka::topic_name = "bro";
```

### `kafka_conf`

The global configuration settings for Kafka.  These values are passed through
directly to librdkafka.  Any valid librdkafka settings can be defined in this
table.  The full set of valid librdkafka settings are available
[here](https://github.com/edenhill/librdkafka/blob/v0.11.5/CONFIGURATION.md).

```
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "localhost:9092",
    ["client.id"] = "bro"
);
```

### `tag_json`

If true, a log stream identifier is appended to each JSON-formatted message. For
example, a Conn::LOG message will look like `{ 'conn' : { ... }}`.

```
redef Kafka::tag_json = T;
```

### `json_timestamps`

Uses Ascii log writer for timestamp format. Default is `JSON::TS_EPOCH`. Other
options are `JSON::TS_MILLIS` and `JSON::TS_ISO8601`.

```
redef Kafka::json_timestamps = JSON::TS_ISO8601;
```

### `max_wait_on_shutdown`

The maximum number of milliseconds that the plugin will wait for any backlog of
queued messages to be sent to Kafka before forced shutdown.

```
redef Kafka::max_wait_on_shutdown = 3000;
```

### `debug`

A comma separated list of debug contexts in librdkafka which you want to
enable.  The available contexts are:
* generic
* broker
* topic
* metadata
* queue
* msg
* protocol
* cgrp
* security
* fetch
* feature
* all  

## Kerberos

This plugin supports producing messages from a kerberized kafka.  There
are a couple of prerequisites and a couple of settings to set.  

### SASL
If you are using SASL as a security protocol for kafka, then you must have
libsasl or libsasl2 installed.  You can tell if sasl is enabled by
running the following from the directory in which you have build
librdkafka:
```
examples/rdkafka_example -X builtin.features
builtin.features = gzip,snappy,ssl,sasl,regex
```

### Producer Config

As stated above, you can configure the producer kafka configs in
`${BRO_HOME}/share/bro/site/local.bro`.  There are a few configs
necessary to set, which are described
[here](https://github.com/edenhill/librdkafka/wiki/Using-SASL-with-librdkafka).
For an environment where the following is true:
* The broker is `node1:6667`
* This kafka is using `SASL_PLAINTEXT` as the security protocol
* The keytab used is the `metron` keytab
* The service principal for `metron` is `metron@EXAMPLE.COM`

The kafka topic `bro` has been given permission for the `metron` user to
write:
```
# login using the metron user
kinit -kt /etc/security/keytabs/metron.headless.keytab metron@EXAMPLE.COM
${KAFKA_HOME}/kafka-broker/bin/kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=node1:2181 --add --allow-principal User:metron --topic bro
```

The following is how the `${BRO_HOME}/share/bro/site/local.bro` looks:
```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::logs_to_send = set(HTTP::LOG, DNS::LOG);
redef Kafka::topic_name = "bro";
redef Kafka::tag_json = T;
redef Kafka::kafka_conf = table( ["metadata.broker.list"] = "node1:6667"
                               , ["security.protocol"] = "SASL_PLAINTEXT"
                               , ["sasl.kerberos.keytab"] = "/etc/security/keytabs/metron.headless.keytab"
                               , ["sasl.kerberos.principal"] = "metron@EXAMPLE.COM"
                               );
```

## Contributing

If you are interested in contributing to this plugin, please see the Apache Metron [CONTRIBUTING.md](https://github.com/apache/metron/blob/master/CONTRIBUTING.md).

