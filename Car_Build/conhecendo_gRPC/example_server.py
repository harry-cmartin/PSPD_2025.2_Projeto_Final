import grpc
import time
from concurrent import futures
import example_pb2
import example_pb2_grpc
import threading

class CommunicatorServicer(example_pb2_grpc.CommunicatorServicer):
    
    # Unary
    def UnaryHello(self, request, context):
        return example_pb2.HelloReply(message=f"Hello, {request.name}!\nWelcome")

    # Server streaming
    def SplitWords(self, request, context):
        words = request.text.split()
        for word in words:
            time.sleep(0.5)
            yield example_pb2.WordReply(word=word.upper())

    # Client streaming
    def Average(self, request_iterator, context):
        total = 0
        count = 0
        for req in request_iterator:
            total += req.number
            count += 1
            print(f"Received: {req.number}")
        avg = total / count if count > 0 else 0
        print(f"Final average: {avg:.2f}")
        return example_pb2.AverageReply(average=avg)

    # Bidirectional streaming
    def Chat(self, request_iterator, context):
        messages_to_send = []
        lock = threading.Lock()
        closed = threading.Event()

        def receive():
            for msg in request_iterator:
                print(f"({msg.sender}) {msg.text}")
            closed.set()

        def send():
            while not closed.is_set():
                text = input("")
                if text.lower() in ["quit", "exit"]:
                    closed.set()
                    break
                with lock:
                    messages_to_send.append(
                        example_pb2.ChatMessage(sender="Server", text=text)
                    )

        threading.Thread(target=receive, daemon=True).start()
        threading.Thread(target=send, daemon=True).start()

        while not closed.is_set():
            with lock:
                while messages_to_send:
                    yield messages_to_send.pop(0)

        print("Connection closed.")

def serve():
    port = '50051'
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    example_pb2_grpc.add_CommunicatorServicer_to_server(CommunicatorServicer(), server)
    server.add_insecure_port(f'[::]:{port}')
    server.start()
    print(f"Server running on port {port}...")
    server.wait_for_termination()

if __name__ == "__main__":
    serve()
