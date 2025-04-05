module EnvHelper
  def with_env(envs = {})
    original = {}
    envs.each do |key, value|
      original[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    original.each do |key, value|
      ENV[key] = value
    end
  end
end
