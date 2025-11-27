## Dependencias

npm install @grpc/grpc-js @grpc/proto-loader

## testar

curl -X POST http://localhost:8000/get-pecas \
  -H "Content-Type: application/json" \
  -d '{"modelo": "fusca", "ano": 2014}'