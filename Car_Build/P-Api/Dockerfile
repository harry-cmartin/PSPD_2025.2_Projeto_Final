FROM python:3.11-slim

# Define o diretório de trabalho
WORKDIR /app

# Copia os arquivos de dependências
COPY requirements.txt .

# Instala as dependências
RUN pip install --no-cache-dir -r requirements.txt

# Copia todo o código da aplicação
COPY . .

# Expõe a porta 8000
EXPOSE 8000

# Comando para iniciar a aplicação com uvicorn
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]