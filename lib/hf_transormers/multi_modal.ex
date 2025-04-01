defmodule InferencePyEx.HfTransformers.MultiModal do
  defstruct initialized: false, globals: nil, functions_loaded: nil

  def new(fields \\ []), do: __struct__(fields)

  def load_model(
        %__MODULE__{} = m,
        model_path,
        auto_model_type,
        model_name \\ "model",
        use_cuda \\ "True"
      ) do
    m = uv_init(m)

    load_model_py =
      """
      import torch
      from transformers import AutoProcessor, <%= @auto_model_type %>

      DEVICE = "cuda" if torch.cuda.is_available() and <%= @use_cuda %> else "cpu"

      model_path = "<%= @model_path %>"
      processor = AutoProcessor.from_pretrained(model_path)
      <%= @model_name %> = <%= @auto_model_type %>.from_pretrained(
        model_path,
        torch_dtype=torch.bfloat16,
      ).to(DEVICE)
      """

    {_, globals} =
      Pythonx.eval(
        EEx.eval_string(
          load_model_py,
          assigns: [
            model_name: model_name,
            model_path: model_path,
            auto_model_type: auto_model_type,
            use_cuda: use_cuda
          ]
        ),
        m.globals
      )

    %{m | globals: globals}
  end

  def unload_model(%__MODULE__{} = m, model_name \\ "model") do
    new_globals = Map.delete(m.globals, model_name)
    %{m | globals: new_globals}
  end

  def prompt_image_from_url(
        %__MODULE__{} = m,
        image_url,
        user_prompt,
        max_predict_tokens \\ 64,
        model_name \\ "model"
      ) do
    m = inference_fns(m, model_name)

    prompt_image_from_url_py =
      """
      prompt_image_from_url("<%= @image_url %>",
        "<%= @user_prompt %>", <%= @max_predict_tokens %>)
      """

    {encoded_response, _globals} =
      Pythonx.eval(
        EEx.eval_string(
          prompt_image_from_url_py,
          assigns: [
            image_url: image_url,
            user_prompt: user_prompt,
            max_predict_tokens: max_predict_tokens
          ]
        ),
        m.globals
      )

    {Pythonx.decode(encoded_response), m}
  end

  def prompt_image_from_path(
        %__MODULE__{} = m,
        path,
        user_prompt,
        max_predict_tokens \\ 64,
        model_name \\ "model"
      ) do
    m = inference_fns(m, model_name)

    prompt_image_from_path_py =
      """
      prompt_image_from_path("<%= @path %>",
        "<%= @user_prompt %>", <%= @max_predict_tokens %>)
      """

    {encoded_response, _globals} =
      Pythonx.eval(
        EEx.eval_string(
          prompt_image_from_path_py,
          assigns: [
            path: path,
            user_prompt: user_prompt,
            max_predict_tokens: max_predict_tokens
          ]
        ),
        m.globals
      )

    {Pythonx.decode(encoded_response), m}
  end

  def prompt_base64_image(
        %__MODULE__{} = m,
        base64_image,
        mime_type,
        user_prompt,
        max_predict_tokens \\ 64,
        model_name \\ "model"
      ) do
    m = inference_fns(m, model_name)

    prompt_base64_image_py =
      """
      prompt_base64_image("<%= @base64_image %>", "<%= @mime_type %>",
        "<%= @user_prompt %>", <%= @max_predict_tokens %>)
      """

    {encoded_response, _globals} =
      Pythonx.eval(
        EEx.eval_string(
          prompt_base64_image_py,
          assigns: [
            base64_image: base64_image,
            mime_type: mime_type,
            user_prompt: user_prompt,
            max_predict_tokens: max_predict_tokens
          ]
        ),
        m.globals
      )

    {Pythonx.decode(encoded_response), m}
  end

  # Pythonx.uv_init can only be called one time.  This function tries
  # to make it easier for other functions to not worry about the requirement
  defp uv_init(%__MODULE__{initialized: already_initialized} = m) do
    if !already_initialized do
      Pythonx.uv_init("""
      [project]
      name = "project"
      version = "0.0.0"
      requires-python = "==3.13.*"
      dependencies = [
        "torch == 2.6.0",
        "transformers == 4.50.0",
        "pillow==11.1.0",
        "num2words==0.5.14"
      ]
      """)

      %__MODULE__{m | initialized: true, globals: %{}}
    else
      m
    end
  end

  defp inference_fns(
         %__MODULE__{functions_loaded: functions_already_loaded, globals: globals} = m,
         model_name
       ) do
    m = uv_init(m)

    if !functions_already_loaded do
      inference_functions_py =
        """
        def prompt_image_from_url(image_url, prompt, return_max_tokens):
          messages = [
            {
                "role": "user",
                "content": [
                  {"type": "image", "url": image_url},
                  {"type": "text", "text": prompt},
                ]
            },
          ]
          return image_chat_response(messages, return_max_tokens)

        def prompt_image_from_path(path, prompt, return_max_tokens):
          messages = [
            {
                "role": "user",
                "content": [
                  {"type": "image", "path": path},
                  {"type": "text", "text": prompt},
                ]
            },
          ]

          return image_chat_response(messages, return_max_tokens)

        def prompt_base64_image(base64_image, mime_type, prompt, return_max_tokens):
          messages = [
            {
                "role": "user",
                "content": [
                  {"type": "image", "url": f"data:{mime_type};base64,{base64_image}"},
                  {"type": "text", "text": prompt},
                ]
            },
          ]
          return image_chat_response(messages, return_max_tokens)

        def image_chat_response(messages, return_max_tokens):
          inputs = processor.apply_chat_template(
            messages,
            add_generation_prompt=False,
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
          ).to(<%= @model_name %>.device, dtype=torch.bfloat16)

          # Generate outputs
          generated_ids = <%= @model_name %>.generate(**inputs, max_new_tokens=return_max_tokens)
          generated_texts = processor.batch_decode(
              generated_ids,
              skip_special_tokens=True,
          )

          return generated_texts[0]
        """

      {_, globals} =
        Pythonx.eval(
          EEx.eval_string(
            inference_functions_py,
            assigns: [
              model_name: model_name
            ]
          ),
          globals
        )

      %__MODULE__{m | functions_loaded: true, globals: globals}
    else
      m
    end
  end
end
