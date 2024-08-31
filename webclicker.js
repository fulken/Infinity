(function () {
    function getRandomInt(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }

    function tapButtonAtCoordinates(clientX, clientY, interval) {
        const evt1 = new PointerEvent('pointerdown', {clientX: clientX, clientY: clientY});
        const evt2 = new PointerEvent('pointerup', {clientX: clientX, clientY: clientY});
        
        setInterval(() => {
            const energyElement = document.querySelector(".user-tap-energy p");
            const buttonElement = document.querySelector(".user-tap-button");
    
            if (energyElement && buttonElement) {
                const energy = parseInt(energyElement.textContent.split(" / ")[0], 10);
                if (energy > 25) {
                    buttonElement.dispatchEvent(evt1);
                    buttonElement.dispatchEvent(evt2);
                }
            }
        }, interval);
    }
    
    // Invoke the function with random parameters for position and speed
    for (let i = 0; i < 7; i++) {
        const randomX = getRandomInt(150, 250); // Random X coordinate between 150 and 250
        const randomY = getRandomInt(300, 450); // Random Y coordinate between 300 and 450
        const randomInterval = getRandomInt(120, 150); // Random interval between 60ms and 300ms
        tapButtonAtCoordinates(randomX, randomY, randomInterval);
    }
})();console.clear();
