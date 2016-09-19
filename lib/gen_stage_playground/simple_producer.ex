defmodule GenStagePlayground.SimpleProducer do
  alias Experimental.GenStage

  use GenStage
  require Logger

  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts)
  end

  # Server API

  def init(opts \\ []) do
    consumers = case Keyword.get(opts, :consumers, :temporary) do
      :temporary -> :temporary
      :permanent -> []
    end

    counter = 0

    {:producer, %{consumers: consumers, counter: counter}}
  end

  # Track both cancellations and subscriptions when consumers: :permanent
  # so we know to shut down after all consumers have shut down
  def handle_subscribe(_, _, _from, %{consumers: :temporary} = state) do
    {:automatic, state}
  end
  def handle_subscribe(_, _, {_, ref}, %{consumers: consumers} = state) do
    {:automatic, %{state | consumers: [ref | consumers]}}
  end

  def handle_cancel(_, _, %{consumers: :temporary} = state) do
    {:noreply, [], state}
  end
  def handle_cancel(_, {_, ref}, %{consumers: consumers} = state) do
    case List.delete(consumers, ref) do
      [] -> {:stop, :normal, %{state | consumers: []}}
      consumers -> {:noreply, [], %{state | consumers: consumers}}
    end
  end

  def handle_demand(demand, %{counter: counter} = state) when demand > 0  and counter >= 10 do
    # Notify consumers we're done. This will start the shutdown process.
    # See
    # https://hexdocs.pm/gen_stage/0.5.0/Experimental.GenStage.html#from_enumerable/2
    GenStage.async_notify(self(), {:producer, :done})
    {:noreply, [], state}
  end

  def handle_demand(demand, %{counter: counter} = state) when demand > 0 do
    Process.sleep(1000)

    Logger.info("demand: #{demand}, counter: #{counter}, pid: #{inspect self}")


    events = Enum.to_list(counter.. counter+demand-1)

    {:noreply, events, %{state | counter: counter+demand}}
  end
end
