# InferencePyEx

Inference library for running Python models under pythonx library.  Initially focusing on running select Hugging Face hosted models that don't have a Bumblebee implementation yet.

Very rough draft to communicate an idea for wrapping models in pythonx.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `inference_py_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:, "~> 0.1.0"}
    {:inference_py_ex, git: "https://github.com/meanderingstream/inference_py_ex"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/inference_py_ex>.

