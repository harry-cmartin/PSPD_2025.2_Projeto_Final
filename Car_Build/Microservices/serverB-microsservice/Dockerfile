FROM node:18-slim

# Define o diretório de trabalho
WORKDIR /app

# Copia o package.json e instala dependências
COPY Microservices/package.json .
RUN npm install

# Cria o diretório protos e copia os arquivos proto
RUN mkdir -p protos
COPY protos/ protos/

# Copia o código do servidor B
COPY Microservices/serverB-microsservice/ .

# Expõe a porta 50052
EXPOSE 50052

# Comando para iniciar o servidor
CMD ["node", "index.js"]