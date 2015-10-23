# MSPP

[![Build Status](https://travis-ci.org/limhoff-r7/mspp.svg?branch=master)](https://travis-ci.org/limhoff-r7/mspp)
[![Coverage Status](https://coveralls.io/repos/limhoff-r7/mspp/badge.svg?branch=master&service=github)](https://coveralls.io/github/limhoff-r7/mspp?branch=master)
[![Inline docs](http://inch-ci.org/github/limhoff-r7/mspp.svg?branch=master)](http://inch-ci.org/github/limhoff-r7/mspp)

Proxy for metasploit-framework payload sessions so you can scale horizontally using one msfconsole

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add mspp to your list of dependencies in `mix.exs`:

        def deps do
          [{:mspp, "~> 0.0.1"}]
        end

  2. Ensure mspp is started before your application:

        def application do
          [applications: [:mspp]]
        end

## Testing

### With `mettle`

#### Single

1. `iex -S mix`
2. `mettle -u 127.0.0.1:8005`

#### Load

1. 
    ```
    for i in `seq 1 100`
    do
      metasploit -u 127.0.0.1:8005 &
    done
    ```
2. Wait for all          
2. `iex -S mix`
