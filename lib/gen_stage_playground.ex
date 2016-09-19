defmodule GenStagePlayground do
  use Application

  alias Experimental.{Flow, GenStage}
  alias GenStagePlayground.SimpleProducer

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      supervisor(Task.Supervisor, [[name: GenStagePlayground.TaskSupervisor, restart: :transient, max_restarts: 3, max_seconds: 500]])
      # Starts a worker by calling: GenStagePlayground.Worker.start_link(arg1, arg2, arg3)
      # worker(GenStagePlayground.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GenStagePlayground.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def play do
    Task.Supervisor.async(GenStagePlayground.TaskSupervisor, fn ->
      {:ok, producer} = SimpleProducer.start_link consumers: :permanent

      Flow.new(stages: 4, max_demand: 2)
      |> Flow.from_stage(producer)
      |> Flow.each(&IO.puts/1)
      |> Flow.map(&(&1 * 2))
      |> Enum.to_list()
    end) |> Task.await(:infinity)
  end
end
