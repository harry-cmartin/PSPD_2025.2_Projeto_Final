import grpc
import example_pb2
import example_pb2_grpc
import threading

def run():
    channel = grpc.insecure_channel('localhost:50051')
    stub = example_pb2_grpc.CommunicatorStub(channel)

    print("1. SayHello - Unary")
    print("2. Uppercase - Server Side Streaming")
    print("3. Average - Client Side Streaming")
    print("4. Chat - Bidirectional Streaming")
    rpc_call = int(input("Which RPC would you like to make: "))
    
    # Unary
    if rpc_call == 1:
        print("Unary:")
        name = input("Enter your name: ")
        response = stub.UnaryHello(example_pb2.HelloRequest(name=name))
        print(response.message)

    # Server streaming
    elif rpc_call == 2:
        print("\nServer streaming:")
        text_buffer = input("Enter a sentence: ")
        print("Server response:")
        for reply in stub.SplitWords(example_pb2.TextRequest(text=text_buffer)):
            print(reply.word)

    # Client streaming
    elif rpc_call == 3:
        print("\nClient streaming:")
        print("Enter numbers (or 'end' to finish):")

        def generate_numbers():
            while True:
                user_input = input("> ")
                if user_input.lower() in ["end", "exit", "quit"]:
                    break
                try:
                    num = float(user_input)
                    yield example_pb2.NumberRequest(number=num)
                except ValueError:
                    print("Invalid input! Please enter a valid number.")

        response = stub.Average(generate_numbers())
        print(f"\nServer calculated average: {response.average:.2f}")

    # Bidirectional streaming
    elif rpc_call == 4:
        name = input("Enter your name: ")

        messages = []
        lock = threading.Lock()
        closed = threading.Event()

        def generate_messages():
            while not closed.is_set():
                with lock:
                    while messages:
                        yield messages.pop(0)

        def read_input():
            while not closed.is_set():
                text = input()
                if text.lower() in ["quit", "exit"]:
                    closed.set()
                    break
                with lock:
                    messages.append(example_pb2.ChatMessage(sender=name, text=text))

        def receive(responses):
            try:
                for response in responses:
                    print(f"({response.sender}): {response.text}")
            except grpc.RpcError:
                pass
            finally:
                closed.set()

        responses = stub.Chat(generate_messages())
        threading.Thread(target=read_input, daemon=True).start()
        receive(responses)
  
if __name__ == "__main__":
    run()
