# Conhcendo o gRPC

## Introdução

O gRPC (Google Remote Procedure Calls) é um framework moderno e de código aberto criado pela Google para viabilizar chamadas de procedimentos remotos (RPC). Diferentemente das APIs REST tradicionais, que utilizam um modelo de requisição/resposta baseado em texto, como JSON, o gRPC foi concebido para oferecer alta performance, eficiência e confiabilidade na comunicação entre serviços, seja em arquiteturas de microserviços, na integração de aplicações móveis com backends ou em sistemas distribuídos complexos.

O objetivo central do gRPC é permitir que a interação entre cliente e servidor — mesmo que implementados em linguagens diferentes — seja tão simples quanto invocar uma função local. Essa abordagem abstrai a complexidade da comunicação de rede, facilitando o desenvolvimento e permitindo que os programadores concentrem seus esforços na lógica de negócio.

## Protocol Buffers

No núcleo do gRPC está o Protocol Buffers (Protobuf), um método de serialização de dados independente de linguagem e plataforma. Diferente de formatos legíveis, como JSON ou XML, o Protobuf organiza os dados em um formato binário compacto. Esse formato é definido em arquivos .proto, nos quais se descrevem as mensagens (estruturas de dados) e os serviços (interfaces com os métodos que podem ser invocados remotamente).

A principal vantagem do Protobuf é sua eficiência: os dados serializados ocupam muito menos espaço e são processados com maior rapidez do que os formatos de texto equivalentes. Isso reduz consideravelmente o consumo de largura de banda e de recursos de CPU, sendo especialmente importante para sistemas que exigem alta escalabilidade e baixa latência.

## HTTP/2
Para transportar esses dados binários de forma eficiente, o gRPC se apoia no HTTP/2 como camada de transporte. Essa escolha vai além de simplesmente gerenciar requisições e respostas: o HTTP/2 oferece funcionalidades avançadas que o gRPC explora plenamente, como multiplexação (permitindo o envio de várias requisições e respostas simultaneamente em uma única conexão TCP, eliminando o bloqueio conhecido como Head-of-Line), compressão de cabeçalhos (reduzindo ainda mais a sobrecarga) e streams bidirecionais. Essa última funcionalidade é especialmente poderosa, pois possibilita que cliente e servidor mantenham uma conexão contínua e troquem múltiplas mensagens de forma assíncrona e em qualquer ordem. Isso habilita cenários complexos, como comunicação em tempo real e streaming de dados.

## Tipos de comunicações suportadas pelo gRCP 

Antes de propriamente avançarmos faz-se necessário especificar o arquivo .proto utilizado a fim de contribuir no esclarecimento dos exemplos que serão apresentados:

```proto
syntax = "proto3";

package example;

service Communicator {

  // Unary call
  rpc UnaryHello(HelloRequest) returns (HelloReply);

  // Server-streaming call
  rpc SplitWords(TextRequest) returns (stream WordReply);

  // Client-streaming call
  rpc Average(stream NumberRequest) returns (AverageReply);

  // Bidirectional streaming call
  rpc Chat(stream ChatMessage) returns (stream ChatMessage);
}

message HelloRequest {
  string name = 1;
}

message HelloReply {
  string message = 1;
}

message TextRequest {
  string text = 1;
}

message WordReply {
  string word = 1;
}

message NumberRequest {
   float number = 1;
}

message AverageReply {
  float average = 1;
}

message ChatMessage {
  string sender = 1;
  string text = 2;
}
```

### Chamda Unária (Unary Call)

A chamada unária é o modelo de comunicação mais simples e familiar, similar a uma requisição HTTP REST tradicional. Neste modelo, o cliente envia uma única requisição para o servidor e recebe uma única resposta de volta. É um paradigma síncrono e bloqueante, onde o cliente aguarda a resposta do servidor para dar continuidade ao processo. Este tipo é ideal para operações que são naturalmente baseadas em uma ação e uma reação imediata, como autenticação de um usuário (envia credenciais, recebe um token), consulta de um dado específico por ID ou processamento de um pagamento.

Para tanto, foi desenvolvido um exemplo simples que demonstra esse tipo de comunicação. Nele, podemos observar claramente o padrão request-response da chamada unária:

**Lado cliente:**

```python
print("Unary:")
name = input("Enter your name: ")  # Cliente prepara a requisição
response = stub.UnaryHello(example_pb2.HelloRequest(name=name))  # Envia UMA requisição
print(response.message)  # Aguarda e recebe UMA resposta
```

**Lado servidor**:

```python
def UnaryHello(self, request, context):
    return example_pb2.HelloReply(message=f"Hello, {request.name}!\nWelcome")  # Processa e retorna UMA resposta
```

Nesta implementação, fica evidente a natureza síncrona e bloqueante da chamada unária. O cliente envia uma única mensagem contendo o nome do usuário através do objeto HelloRequest e bloqueia a execução, aguardando necessariamente que o servidor processe a requisição e retorne uma única resposta do tipo HelloReply. O servidor, por sua vez, recebe a requisição completa, processa a lógica de negócio (nesse caso, a simples formatação de uma mensagem de saudação) e envia a resposta de volta de uma vez, finalizando a transação.

### Streaming do Servidor (Server Streaming RPC)

No streaming do servidor, o cliente envia uma única requisição e, em contrapartida, recebe um fluxo (stream) de múltiplas mensagens como resposta.O servidor mantém a conexão aberta e pode enviar dados de forma contínua até que a transação seja finalizada. Este modelo é perfeito para cenários onde o servidor precisa transmitir uma grande quantidade de dados que são gerados ou buscados de forma progressiva. Exemplos clássicos incluem notificações em tempo real (como alertas de sistema), o envio de um arquivo grande em pedaços (chunks) ou o recebimento de atualizações em tempo real de uma cotação de ações.

Em relação a essa comunicação, no exemplo desenvolvido o cliente envia uma única requisição contendo uma frase completa, e o servidor responde com um fluxo de mensagens individuais, onde cada palavra é enviada sequencialmente:

**Lado cliente:**
```python
print("\nServer streaming:")
text_buffer = input("Enter a sentence: ")  # Cliente envia UMA requisição
print("Server response:")
for reply in stub.SplitWords(example_pb2.TextRequest(text=text_buffer)):
    print(reply.word)  # Recebe MÚLTIPLAS respostas em streaming
```

**Lado servidor**:
```python
def SplitWords(self, request, context):
    words = request.text.split()
    for word in words:
        time.sleep(0.5)  # Simula processamento ou delay
        yield example_pb2.WordReply(word=word.upper())  # Retorna múltipla respostas via yield
```
Esta implementação demonstra elegantemente as características essenciais do server streaming. O cliente faz uma única chamada ao método SplitWords, mas em vez de receber uma resposta única, entra em um loop que itera sobre um fluxo contínuo de respostas. Cada palavra da frase original é processada e enviada individualmente pelo servidor, com um delay de 0.5 segundos entre elas, simulando um processamento progressivo ou a transmissão de dados que são gerados em tempo real.

### Streaming do Cliente (Client Streaming RPC)

No streaming do cliente, a dinâmica se inverte: o cliente envia um fluxo (stream) de múltiplas mensagens para o servidor e, ao finalizar o envio, recebe uma única resposta. Isso permite que o cliente faça um upload de dados de forma eficiente e contínua, sem precisar acumular tudo na memória antes de enviar. O servidor, por sua vez, processa todo o fluxo de dados recebido e retorna uma única resposta de confirmação ou agregação. Um uso comum é o upload de um arquivo muito grande, onde o cliente envia os pedaços sequencialmente. Outro exemplo é a agregação de métricas de diversos dispositivos IoT, onde o servidor consolida todos os dados recebidos em um único relatório.

Assim, no exemplo proposto, temos uma implementação clássica de client streaming que demonstra exatamente a inversão de papéis descrita conceitualmente. O cliente envia um fluxo contínuo de números para que o servidor calcule e retorne uma única resposta com a média aritmética:

**Lado cliente:**

```python
print("\nClient streaming:")
print("Enter numbers (or 'end' to finish):")

def generate_numbers():
    while True:
        user_input = input("> ")  # Cliente coleta dados continuamente
        if user_input.lower() in ["end", "exit", "quit"]:
            break
        try:
            num = float(user_input)
            yield example_pb2.NumberRequest(number=num)  # Envia múltiplas requisições via yield
        except ValueError:
            print("Invalid input! Please enter a valid number.")

response = stub.Average(generate_numbers())  # Recebe UMA resposta final
print(f"\nServer calculated average: {response.average:.2f}")
```

Lado Servirdor:

```python
def Average(self, request_iterator, context):
    total = 0
    count = 0
    for req in request_iterator:  # Processa o fluxo de requisições
        total += req.number
        count += 1
        print(f"Received: {req.number}")
    avg = total / count if count > 0 else 0
    print(f"Final average: {avg:.2f}")
    return example_pb2.AverageReply(average=avg)  # Retorna UMA resposta consolidada
```

Esta implementação captura perfeitamente a essência do client streaming. O cliente utiliza um generator (generate_numbers()) para enviar números de forma assíncrona e contínua, mantendo o controle sobre quando iniciar e finalizar o envio dos dados. O servidor, por sua vez, recebe um iterador (request_iterator) que lhe permite processar cada número individualmente à medida que chega, acumulando os valores para o cálculo final.

### Streaming Bidirecional (Bidirectional Streaming RPC)

Já o streaming bidirecional é o modelo mais flexível e complexo, permitindo que cliente e servidor enviem um fluxo de mensagens de forma independente e assíncrona. As duas pontas da comunicação podem ler, escrever e operar simultaneamente, sem uma ordem predeterminada. Essa capacidade é habilitada pelo HTTP/2, que permite a multiplexação em uma única conexão. Este padrão é extremamente poderoso para aplicações que exigem interação em tempo real e comunicação contínua. Casos de uso notáveis incluem sistemas de chat em grupo, jogos multiplayer onde a posição de vários jogadores é atualizada constantemente, ou aplicações de negociação em bolsa, onde ambas as partes estão constantemente enviando e recebendo ordens de compra e venda.

Logo, para tal comunicação o exemplo desenvolvido foi um sistema de chat em tempo real que demonstra toda a potência e complexidade do streaming bidirecional. A implementação cria um canal de comunicação totalmente assíncrono onde cliente e servidor podem trocar mensagens livremente e simultaneamente:

**Lado cliente:**

```python
def generate_messages():
    while not closed.is_set():
        with lock:
            while messages:
                yield messages.pop(0)  # Envia mensagens do cliente

def read_input():
    while not closed.is_set():
        text = input()  # Captura input do usuário em tempo real
        messages.append(example_pb2.ChatMessage(sender=name, text=text))

def receive(responses):
    for response in responses:
        print(f"({response.sender}): {response.text}")  # Recebe mensagens do servidor

# Execução paralela dos fluxos
threading.Thread(target=read_input, daemon=True).start()
receive(responses)
```

**Lado servidor**:

```python
def Chat(self, request_iterator, context):
    def receive():
        for msg in request_iterator:  # Recebe mensagens do cliente
            print(f"({msg.sender}) {msg.text}")

    def send():
        while not closed.is_set():
            text = input("")  # Captura input do servidor
            messages_to_send.append(example_pb2.ChatMessage(sender="Server", text=text))

    # Threads para receber e enviar simultaneamente
    threading.Thread(target=receive, daemon=True).start()
    threading.Thread(target=send, daemon=True).start()

    while not closed.is_set():
        with lock:
            while messages_to_send:
                yield messages_to_send.pop(0)  # Envia mensagens do servidor
```

Nesta implementação através do uso de threads paralelas tanto no cliente quanto no servidor, conseguimos a verdadeira independência dos fluxos de comunicação - o cliente pode digitar e enviar mensagens enquanto simultaneamente recebe e exibe mensagens do servidor, e vice-versa.

A chave está na multiplexação do HTTP/2 que permite que ambos os streams (cliente→servidor e servidor→cliente) coexistam na mesma conexão TCP sem bloqueio mútuo. O generator generate_messages() no cliente e o loop while com yield no servidor mantêm os canais abertos continuamente, permitindo que mensagens sejam enviadas e recebidas em qualquer ordem, a qualquer momento.