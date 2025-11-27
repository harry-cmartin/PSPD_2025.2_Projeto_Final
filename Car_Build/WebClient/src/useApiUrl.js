// Configuração simples da API URL
export const getApiUrl = () => {
  return process.env.REACT_APP_API_URL || "http://localhost:8000";
};

export const useApiUrl = () => {
  const apiUrl = getApiUrl();
  console.log(`Usando API URL: ${apiUrl}`);

  return {
    apiUrl,
    isDetecting: false,
    detectApiUrl: () => Promise.resolve(apiUrl),
  };
};
