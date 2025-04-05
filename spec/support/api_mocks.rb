module ApiMocks
  def stub_ollama_model_list(host, models = ["llama3"])
    stub_request(:get, "#{host}/api/tags")
      .to_return(
        status: 200, 
        body: { models: models.map { |m| { name: m } } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def stub_ollama_chat_streaming(host, model, response_chunks)
    stub_request(:post, "#{host}/api/chat")
      .with(
        body: hash_including(model: model, stream: true)
      )
      .to_return(
        status: 200,
        body: response_chunks.map(&:to_json).join("\n"),
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end