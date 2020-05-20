# Logging Zeek Output to Kafka

A Zeek log writer that sends logging output to Kafka.  This provides a convenient means for tools in the Hadoop ecosystem, such as Storm, Spark, and others, to process the data generated by Zeek.

This software is a part of the [Apache Metron](https://metron.apache.org/) project which integrates a variety of open source, big data technologies to offer a platform to detect and respond to cyber threats at-scale.

* [Installation](#installation)
* [Activation](#activation)
* [Settings](#settings)
* [Kerberos](#kerberos)
* [Contributing](#contributing)

## Installation

### `zkg` Installation

`zkg` is the preferred mechanism for installing this plugin, as it will dynamically retrieve, build, test, and load the plugin.  Note, that you will still need to [activate](#activation) and configure the plugin after your installation.

1. Install [librdkafka](https://github.com/edenhill/librdkafka), a native client library for Kafka.  This plugin has been tested against librdkafka v1.4.2.

    In order to use this plugin within a kerberized Kafka environment, you will also need `libsasl2` installed and will need to pass `--enable-sasl` to the `configure` script.

    ```
    $ curl -L https://github.com/edenhill/librdkafka/archive/v1.4.2.tar.gz | tar xvz
    $ cd librdkafka-1.4.2/
    $ ./configure --enable-sasl
    $ make
    $ sudo make install
    ```

1. Configure `zkg` by following the quickstart guide [here](https://docs.zeek.org/projects/package-manager/en/stable/quickstart.html).

1. Install the plugin using `zkg install`.

    ```
    $ zkg install apache/metron-bro-plugin-kafka --version master
    The following packages will be INSTALLED:
      zeek/apache/metron-bro-plugin-kafka (master)

    Verify the following REQUIRED external dependencies:
    (Ensure their installation on all relevant systems before proceeding):
      from zeek/apache/metron-bro-plugin-kafka (master):
        librdkafka ~1.4.2

    Proceed? [Y/n]
    zeek/apache/metron-bro-plugin-kafka asks for LIBRDKAFKA_ROOT (Path to librdkafka installation tree) ? [/usr/local/lib]
    Saved answers to config file: /home/jonzeolla/.zkg/config
    Running unit tests for "zeek/apache/metron-bro-plugin-kafka"
    all 10 tests successful


    Installing "zeek/apache/metron-bro-plugin-kafka"........
    Installed "zeek/apache/metron-bro-plugin-kafka" (master)
    Loaded "zeek/apache/metron-bro-plugin-kafka"
    ```

1. Run the following command to ensure that the plugin was installed successfully.

    ```
    $ zeek -N Apache::Kafka
    Apache::Kafka - Writes logs to Kafka (dynamic, version 0.3.0)
    ```

### Manual Installation

Manually installing the plugin should *only* occur in situations where installing and configuring `zkg` is not reasonable.  If you are running zeek in an environment where you do not have Internet connectivity, investigate [bundles](https://docs.zeek.org/projects/package-manager/en/stable/zkg.html#bundle) or creating an internal [package source](https://docs.zeek.org/projects/package-manager/en/stable/source.html).

These instructions could also be helpful if you were interested in distributing this as a package (such as a deb or rpm).

1. Install [librdkafka](https://github.com/edenhill/librdkafka), a native client library for Kafka.  This plugin has been tested against librdkafka v1.4.2.

    In order to use this plugin within a kerberized Kafka environment, you will also need `libsasl2` installed and will need to pass `--enable-sasl` to the `configure` script.

    ```
    $ curl -L https://github.com/edenhill/librdkafka/archive/v1.4.2.tar.gz | tar xvz
    $ cd librdkafka-1.4.2/
    $ ./configure --enable-sasl
    $ make
    $ sudo make install
    ```

1. Build the plugin using the following commands.

    ```
    $ ./configure --with-librdkafka=$librdkafka_root
    $ make
    $ sudo make install
    ```

1. Run the following command to ensure that the plugin was installed successfully.

    ```
    $ zeek -N Apache::Kafka
    Apache::Kafka - Writes logs to Kafka (dynamic, version 0.3.0)
    ```

## Activation

The following examples highlight different ways that the plugin can be used.  Simply add the Zeek script language to your `local.zeek` file (for example, `/usr/share/zeek/site/local.zeek`) as shown to demonstrate the example.

In addition to activating the plugin, when running Zeek in a cluster it is highly recommended to leverage one or more Zeek [loggers](https://docs.zeek.org/en/v3.1.2/cluster/index.html#logger) as shown [here](https://docs.zeek.org/en/v3.1.2/configuration/index.html#basic-cluster-configuration) to separate logging activities from the manager thread.

### Example 1 - Send a list of logs to kafka

The goal in this example is to send all HTTP and DNS records to a Kafka topic named `zeek`.
 * Any configuration value accepted by librdkafka can be added to the `kafka_conf` configuration table.  
 * The `topic_name` will default to send all records to a single Kafka topic called 'zeek'.
 * Defining `logs_to_send` will send the HTTP and DNS records to the brokers specified in your `Kafka::kafka_conf`.
```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::logs_to_send = set(HTTP::LOG, DNS::LOG);
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "server1.example.com:9092,server2.example.com:9092"
);
```

### Example 2 - Send all active logs

This plugin has the ability send all active logs to the "zeek" kafka topic with the following configuration.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::send_all_active_logs = T;
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "localhost:9092"
);
```

### Example 3 - Send all active logs with exclusions

You can also specify a blacklist of zeek logs to ensure they aren't being sent to kafka regardless of the `Kafka::send_all_active_logs` and `Kafka::logs_to_send` configurations.  In this example, we will send all of the enabled logs except for the Conn log.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::send_all_active_logs = T;
redef Kafka::logs_to_exclude = set(Conn::LOG);
redef Kafka::topic_name = "zeek";
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "localhost:9092"
);
```

### Example 4 - Send each zeek log to a unique topic

It is also possible to send each log stream to a uniquely named topic.  The goal in this example is to send all HTTP records to a Kafka topic named `http` and all DNS records to a separate Kafka topic named `dns`.
 * The `topic_name` value must be set to an empty string.
 * The `$path` value of Zeek's Log Writer mechanism is used to define the topic name.
 * Any configuration value accepted by librdkafka can be added to the `$config` configuration table.  
 * Each log writer accepts a separate configuration table.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::topic_name = "";
redef Kafka::tag_json = T;

event zeek_init() &priority=-10
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

#### Dynamically send each zeek log to a topic with its same name.

 * ej. `CONN::LOG` logs are sent to the `conn` topic or `Known::CERTS_LOG` to the `known-certs` topic.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::logs_to_send = set(DHCP::LOG, RADIUS::LOG, DNS::LOG);
redef Kafka::topic_name = "";
redef Kafka::tag_json = T;

event zeek_init() &priority=-10
{
    for (stream_id in Log::active_streams) {
        # Convert stream type enum to string
        const stream_string: string = fmt("%s", stream_id);

        # replace `::` by `_` from the log string name
	    # ej. CONN::LOG to CONN_LOG or Known::CERTS_LOG to Known_CERTS_LOG
        const stream_name: string = sub(stream_string, /::/, "_");

        # lowercase the whole string for nomalization
        const topic_name_lower: string = to_lower(stream_name);

        # remove the _log at the of each topic name
        const topic_name_under: string = sub(topic_name_lower, /_log$/, "");

        # replace `_` by `-` for compatibility with acceptable Kafka topic naes
        const topic_name: string = sub(topic_name_under, /_/, "-");

        if (|Kafka::logs_to_send| == 0 || stream_id in Kafka::logs_to_send)
        {
            local log_filter: Log::Filter = [
                $name = fmt("kafka-%s", stream_id),
                $writer = Log::WRITER_KAFKAWRITER,
                $path = fmt("%s", topic_name)
            ];
            Log::add_filter(stream_id, log_filter);
        }
    }
}
```

### Example 5 - Zeek log filtering

You may want to configure zeek to filter log messages with certain characteristics from being sent to your kafka topics.  For instance, Apache Metron currently doesn't support IPv6 source or destination IPs in the default enrichments, so it may be helpful to filter those log messages from being sent to kafka (although there are [multiple ways](#notes) to approach this).  In this example we will do that that, and are assuming a somewhat standard zeek kafka plugin configuration, such that:
 * All zeek logs are sent to the default `zeek` topic.
 * Each JSON message is tagged with the appropriate log type (such as `http`, `dns`, or `conn`), by setting `Kafka::tag_json` to true.
 * If the log message contains a 128 byte long source or destination IP address, the log is not sent to kafka.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::tag_json = T;

event zeek_init() &priority=-10
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
 * The [`is_v6_addr()`](https://docs.zeek.org/en/v3.1.2/scripts/base/bif/zeek.bif.zeek.html#id-is_v6_addr) function can also be used in your `$pred` to identify if an IP address is IPv6.
 * Alternatively, if you are using Apache Metron to pull from the specified kafka topic, you could filter the IPv6 logs [using Stellar](https://metron.apache.org/current-book/metron-stellar/stellar-common/index.html#IS_IP).  In that case Stellar would filter the logs out and a `$pred` would not be necessary.  The benefit to this approach is that kafka would receive an unfiltered set of logs.

### Example 6 - Sending a log to multiple topics

You are able to send a single zeek log to multiple different kafka topics in the same kafka cluster by overriding the default topic (configured with `Kafka::topic_name`) by creating a custom zeek `Log::Filter`.  In this example, the DHCP, RADIUS, and DNS logs are sent to the "zeek" topic; the RADIUS log is duplicated to the "shew_zeek_radius" topic; and the DHCP log is duplicated to the "shew_zeek_dhcp" topic.

```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::logs_to_send = set(DHCP::LOG, RADIUS::LOG, DNS::LOG);
redef Kafka::topic_name = "zeek";
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "server1.example.com:9092,server2.example.com:9092"
);
redef Kafka::tag_json = T;

event zeek_init() &priority=-10
{
    # Send RADIUS to the shew_zeek_radius topic
    local shew_radius_filter: Log::Filter = [
        $name = "kafka-radius-shew",
        $writer = Log::WRITER_KAFKAWRITER,
        $path = "shew_zeek_radius"
        $config = table(["topic_name"] = "shew_zeek_radius")
    ];
    Log::add_filter(RADIUS::LOG, shew_radius_filter);

    # Send DHCP to the shew_zeek_dhcp topic
    local shew_dhcp_filter: Log::Filter = [
        $name = "kafka-dhcp-shew",
        $writer = Log::WRITER_KAFKAWRITER,
        $path = "shew_zeek_dhcp"
        $config = table(["topic_name"] = "shew_zeek_dhcp")
    ];
    Log::add_filter(DHCP::LOG, shew_dhcp_filter);
}
```

_Note_:  Because `Kafka::tag_json` is set to True in this example, the value of `$path` is used as the tag for each `Log::Filter`. If you were to add a log filter with the same `$path` as an existing filter, Zeek will append "-N", where N is an integer starting at 2, to the end of the log path so that each filter has its own unique log path. For instance, the second instance of `conn` would become `conn-2`.

### Example 7 - Add static values to each outgoing Kafka message
It is possible to define name value pairs and have them added to each outgoing Kafka json message when tagged_json is set to true.  Each will be added to the root json object.
    * the Kafka::additional_message_values table can be configured with each name and value
    * based on the following configuration, each outgoing message will have "FIRST_STATIC_NAME": "FIRST_STATIC_VALUE", "SECOND_STATIC_NAME": "SECOND_STATIC_VALUE" added.
```
@load packages
redef Kafka::logs_to_send = set(HTTP::LOG, DNS::LOG, Conn::LOG, DPD::LOG, FTP::LOG, Files::LOG, Known::CERTS_LOG, SMTP::LOG, SSL::LOG, Weird::LOG, Notice::LOG, DHCP::LOG, SSH::LOG, Software::LOG, RADIUS::LOG, X509::LOG, RFB::LOG, Stats::LOG, CaptureLoss::LOG, SIP::LOG);
redef Kafka::topic_name = "zeek";
redef Kafka::tag_json = T;
redef Kafka::kafka_conf = table(["metadata.broker.list"] = "kafka-1:9092,kafka-2:9092");
redef Kafka::additional_message_values = table(["FIRST_STATIC_NAME"] = "FIRST_STATIC_VALUE", ["SECOND_STATIC_NAME"] = "SECOND_STATIC_VALUE");
redef Kafka::logs_to_exclude = set(Conn::LOG, DHCP::LOG);
redef Known::cert_tracking = ALL_HOSTS;
redef Software::asset_tracking = ALL_HOSTS;
```

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

The name of the topic in Kafka where all Zeek logs will be sent to.

```
redef Kafka::topic_name = "zeek";
```

### `kafka_conf`

The global configuration settings for Kafka.  These values are passed through
directly to librdkafka.  Any valid librdkafka settings can be defined in this
table.  The full set of valid librdkafka settings are available
[here](https://github.com/edenhill/librdkafka/blob/v1.4.2/CONFIGURATION.md).

```
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "localhost:9092",
    ["client.id"] = "zeek"
);
```

### `additonal_message_values`

A table of of name value pairs.  Each item in this table will be added to each outgoing message
at the root level if tag_json is set to T.

```
redef Kafka::additional_message_values = table(
    ["FIRST_STATIC_NAME"] = "FIRST_STATIC_VALUE",
    ["SECOND_STATIC_NAME"] = "SECOND_STATIC_VALUE"
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
* all
* generic
* broker
* topic
* metadata
* feature
* queue
* msg
* protocol
* cgrp
* security
* fetch
* feature
* interceptor
* plugin
* consumer
* admin

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
`${ZEEK_HOME}/share/zeek/site/local.zeek`.  There are a few configs
necessary to set, which are described
[here](https://github.com/edenhill/librdkafka/wiki/Using-SASL-with-librdkafka).
For an environment where the following is true:
* The broker is `node1:6667`
* This kafka is using `SASL_PLAINTEXT` as the security protocol
* The keytab used is the `metron` keytab
* The service principal for `metron` is `metron@EXAMPLE.COM`

The kafka topic `zeek` has been given permission for the `metron` user to
write:
```
# login using the metron user
kinit -kt /etc/security/keytabs/metron.headless.keytab metron@EXAMPLE.COM
${KAFKA_HOME}/kafka-broker/bin/kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=node1:2181 --add --allow-principal User:metron --topic zeek
```

The following is how the `${ZEEK_HOME}/share/zeek/site/local.zeek` looks:
```
@load packages/metron-bro-plugin-kafka/Apache/Kafka
redef Kafka::logs_to_send = set(HTTP::LOG, DNS::LOG);
redef Kafka::topic_name = "zeek";
redef Kafka::tag_json = T;
redef Kafka::kafka_conf = table( ["metadata.broker.list"] = "node1:6667"
                               , ["security.protocol"] = "SASL_PLAINTEXT"
                               , ["sasl.kerberos.keytab"] = "/etc/security/keytabs/metron.headless.keytab"
                               , ["sasl.kerberos.principal"] = "metron@EXAMPLE.COM"
                               );
```

## Contributing

If you are interested in contributing to this plugin, please see the Apache Metron [CONTRIBUTING.md](https://github.com/apache/metron/blob/master/CONTRIBUTING.md).

