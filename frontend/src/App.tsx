import { useState } from 'react';

function App() {
  const [file, setFile] = useState<File | null>(null);
  const [message, setMessage] = useState('');

  const handleUpload = async () => {
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await fetch('https://<TU_API_GATEWAY_ENDPOINT>', {
        method: 'POST',
        body: file,
      });

      const data = await res.json();
      setMessage(data.body || 'Imagen subida exitosamente');
    } catch (error) {
      console.error(error);
      setMessage('Error al subir la imagen');
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
