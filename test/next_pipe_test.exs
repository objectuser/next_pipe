defmodule NextPipeTest do
  use ExUnit.Case

  import NextPipe

  describe "next/2" do
    test "{:ok, _} calls function" do
      assert {:ok, :one} == next({:ok, :zero}, fn :zero -> {:ok, :one} end)
    end

    test "multiple function arguments are fine" do
      arg1 = :one
      arg2 = :two

      fn1 = fn arg1, arg2 ->
        if arg1 == arg2 do
          {:ok, arg1}
        else
          {:ok, arg2}
        end
      end

      assert {:ok, :two} ==
               arg1
               |> next(&fn1.(&1, arg2))
    end

    test "{:error, _} skips function" do
      assert {:error, :zero} == next({:error, :zero}, fn :zero -> {:ok, :one} end)
    end

    test "otherwise calls the function" do
      assert {:ok, :one} ==
               :zero
               |> next(&zero/1)
    end

    defp zero(:zero), do: {:ok, :one}
  end

  describe "always/2" do
    test "{:ok, _} calls function" do
      assert {:ok, :one} == always({:ok, :zero}, fn {:ok, :zero} -> {:ok, :one} end)
    end

    test "{:error, _} calls function" do
      assert {:ok, :one} == always({:error, :zero}, fn {:error, :zero} -> {:ok, :one} end)
    end
  end

  describe "try_next/3" do
    test "{:ok, _} calls function" do
      assert {:ok, :one} ==
               try_next(
                 {:ok, :zero},
                 fn :zero -> {:ok, :one} end,
                 fn :zero -> {:ok, :two} end
               )
    end

    test "{:error, _} skips function" do
      assert {:error, :zero} ==
               try_next(
                 {:error, :zero},
                 fn :zero -> {:ok, :one} end,
                 fn :zero -> {:ok, :two} end
               )
    end

    test "otherwise calls function" do
      assert {:ok, :one} ==
               try_next(
                 :zero,
                 fn :zero -> {:ok, :one} end,
                 fn :zero -> {:ok, :two} end
               )
    end

    test "exception calls rescue function" do
      assert {:error, :two} ==
               try_next(
                 {:ok, :zero},
                 fn :zero -> raise "error" end,
                 fn :zero, %RuntimeError{message: "error"} -> {:error, :two} end
               )
    end

    test "otherwise rescues and calls the rescue function" do
      assert {:error, :two} ==
               try_next(
                 :zero,
                 fn :zero -> raise "error" end,
                 fn :zero, %RuntimeError{message: "error"} -> {:error, :two} end
               )
    end
  end

  describe "on_error/2" do
    test "{:error, _} calls function" do
      assert {:ok, :one} == on_error({:error, :zero}, fn :zero -> {:ok, :one} end)
    end

    test "{:ok, _} skips function" do
      assert {:ok, :zero} == on_error({:ok, :zero}, fn :notcalled -> {:ok, :one} end)
    end
  end
end
