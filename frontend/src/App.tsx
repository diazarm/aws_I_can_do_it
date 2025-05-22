import { useState } from 'react';

function App() {
  const [file, setFile] = useState<File | null>(null);
  const [message, setMessage] = useState('');

  const handleUpload = async () => {
    if (!file) return;

    try {
      const arrayBuffer = await file.arrayBuffer();
      const base64File = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));

      const res = await fetch("https://ur2l31zaj4.execute-api.us-east-1.amazonaws.com/prod/upload", {
        method: 'POST',
        headers: {
          'Content-Type': 'application/octet-stream',
          'filename': file.name,
        },
        body: base64File,
      });

      const text = await res.text(); // Leemos como texto por si no es JSON

      let data;
      try {
        data = JSON.parse(text);
      } catch {
        throw new Error("Respuesta no es JSON válido: " + text);
      }

      if (!res.ok) throw new Error(data.error || "Error en el servidor");

      setMessage(data.message || 'Imagen subida exitosamente');
    } catch (error: unknown) {
      console.error(error);
      if (error instanceof Error) {
        setMessage(error.message || 'Error al subir la imagen');
      } else {
        setMessage('Error al subir la imagen');
      }
    }
  };

  return (
    <div style={{ padding: '2rem' }}>
      <h1>Subí tu imagen</h1>
      <input type="file" accept="image/*" onChange={e => setFile(e.target.files?.[0] || null)} />
      <button onClick={handleUpload}>Subir</button>
      <p>{message}</p>
    </div>
  );
}

export default App;
