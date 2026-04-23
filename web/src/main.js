import '@fontsource-variable/manrope/wght.css';
import '@fontsource-variable/jetbrains-mono/wght.css';
import './styles/tokens.css';
import { mount } from 'svelte';
import App from './App.svelte';

const app = mount(App, { target: document.getElementById('app') });

export default app;
